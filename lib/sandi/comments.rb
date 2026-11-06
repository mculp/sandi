# frozen_string_literal: true

require "prism"

module Sandi
  # The comments in a file that are written for a reader, each with the code it is about: a comment just above a class,
  # module or def is about that definition, and a comment on its own lines in a method is about the method. Shebangs,
  # magic comments and rubocop: directives are written for tools, so they are left out of a comment, though one between
  # a comment and its definition doesn't separate them. A comment after code on its line is left alone.
  class Comments
    Comment = Data.define(:file, :line, :text, :code) do
      # What Jev reads to answer a question about the comment.
      def state = {"comment" => text, "code" => code}
    end
    DEFINITIONS = %i[class_node module_node singleton_class_node def_node].freeze
    DIRECTIVE = /\A#(!|\s*rubocop:)/
    # The code sent with a comment stops after a class's worth of lines, so code within the first rule is sent whole.
    LINES = 100

    def self.of(file, root:) = new(file, Prism.parse_file(File.join(root, file))).to_a

    def initialize(file, parse)
      @file, @parse = file, parse
    end

    def to_a = paragraphs.filter_map { |paragraph| about(paragraph) }

    private

    def about(paragraph)
      said = paragraph.reject { |comment| for_tools?(comment) }
      node = documented(paragraph) || method_around(paragraph)
      Comment.new(@file, line(said.first), text(said), code(node, said.first)) if node && said.any?
    end

    # Comment lines next to each other, each on a line of its own, are one comment.
    def paragraphs = own_lines.slice_when { |above, below| line(below) != line(above) + 1 }
    def own_lines = @parse.comments.select { |comment| comment.is_a?(Prism::InlineComment) && !comment.trailing? }
    def for_tools?(comment) = comment.location.slice.match?(DIRECTIVE) || magic?(comment)
    def magic?(comment) = @parse.magic_comments.any? { |magic| magic.key_loc.start_line == line(comment) }

    def documented(paragraph) = definitions.find { |node| node.location.start_line == line(paragraph.last) + 1 }

    # The innermost method the comment is in, which of all that hold it is the one to end first.
    def method_around(paragraph)
      methods = definitions.select { |node| node.type == :def_node && around?(node, paragraph) }
      methods.min_by { |node| node.location.end_line }
    end

    def around?(node, paragraph)
      node.location.start_line < line(paragraph.first) && line(paragraph.last) < node.location.end_line
    end

    def definitions = @definitions ||= nodes(@parse.value).select { |node| DEFINITIONS.include?(node.type) }
    def nodes(node) = [node, *node.compact_child_nodes.flat_map { |child| nodes(child) }]

    def text(paragraph) = paragraph.map { |comment| comment.location.slice.delete_prefix("#").delete_prefix(" ") }.join("\n")
    # At most LINES lines of the definition: all of it, or when it is longer, its first lines, or the lines around the
    # comment if the comment is further in.
    def code(node, comment)
      last = node.location.end_line
      from = [node.location.start_line, [line(comment) - LINES / 2, last - LINES + 1].min].max
      source[from - 1, [last - from + 1, LINES].min].join
    end

    def source = @source ||= @parse.source.source.lines
    def line(comment) = comment.location.start_line
  end
end
