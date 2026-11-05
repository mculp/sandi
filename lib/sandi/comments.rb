# frozen_string_literal: true

require "prism"

module Sandi
  # The comments in a file that are written for a reader, each with the code it is about: a comment just above a class,
  # module or def is about that definition, and a comment on its own lines in a method is about the method. Shebangs,
  # magic comments and rubocop: directives are written for tools, and a comment after code on its line is left alone.
  class Comments
    Comment = Data.define(:file, :line, :text, :code)
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
      node = documented(paragraph) || method_around(paragraph)
      Comment.new(@file, line(paragraph.first), text(paragraph), code(node)) if node
    end

    # Comment lines next to each other are one comment.
    def paragraphs = for_readers.slice_when { |above, below| line(below) != line(above) + 1 }
    def for_readers = @parse.comments.select { |comment| comment.is_a?(Prism::InlineComment) && !for_tools?(comment) }
    def for_tools?(comment) = comment.trailing? || comment.location.slice.match?(DIRECTIVE) || magic?(comment)
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
    def code(node) = source[node.location.start_line - 1, [length(node), LINES].min].join
    def length(node) = node.location.end_line - node.location.start_line + 1
    def source = @source ||= @parse.source.source.lines
    def line(comment) = comment.location.start_line
  end
end
