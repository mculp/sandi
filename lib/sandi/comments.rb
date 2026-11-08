# frozen_string_literal: true

require_relative "source"

module Sandi
  # The comments in a file that are written for a reader, each with the code it is about: a comment just above a class,
  # module or def is about that definition, one on its own lines in a method is about the method, one just above any
  # other statement, such as a constant or a require, is about that statement, and one anywhere else in a statement is
  # about the smallest statement that holds it. Shebangs, magic comments and rubocop: directives are written for tools,
  # so they are left out of a comment, though one between a comment and the code under it doesn't separate them. A
  # comment after code on its line is TrailingComments's, and one that no statement holds is not read.
  class Comments
    Comment = Data.define(:file, :line, :text, :code) do
      # What Jev reads to answer a question about the comment.
      def state = {"comment" => text, "code" => code}

      # How a message points at the comment, beside its line.
      def first_line = text.strip[/.*/].strip
    end
    DEFINITIONS = %i[class_node module_node singleton_class_node def_node].freeze
    DIRECTIVE = /\A#(!|\s*rubocop:)/

    def initialize(source)
      @source = source
    end

    def to_a = paragraphs.filter_map { |paragraph| about(paragraph) }

    private

    def about(paragraph)
      said = paragraph.reject { |comment| for_tools?(comment) }
      node = subject(paragraph)
      Comment.new(@source.file, line(said.first), text(said), code(node, said.first)) if node && said.any?
    end

    # What a comment is about, in the order it is looked for: the definition just under it, the method it is in, the
    # statement just under it, and the smallest statement that holds it.
    def subject(paragraph)
      documented(paragraph) || method_around(paragraph) || beneath(paragraph) || holding(paragraph)
    end

    # Comment lines next to each other, each on a line of its own, are one comment.
    def paragraphs = own_lines.slice_when { |above, below| line(below) != line(above) + 1 }
    def own_lines = inline.reject(&:trailing?)
    def inline = @source.comments.grep(Prism::InlineComment)
    def for_tools?(comment) = comment.location.slice.match?(DIRECTIVE) || magic?(comment)
    def magic?(comment) = @source.magic_comments.any? { |magic| magic.key_loc.start_line == line(comment) }

    def documented(paragraph) = definitions.find { |node| node.location.start_line == line(paragraph.last) + 1 }

    # The innermost method the comment is in, which of all that hold it is the one to end first.
    def method_around(paragraph)
      methods = @source.method_nodes.select { |node| around?(node, paragraph) }
      methods.min_by { |node| node.location.end_line }
    end

    def around?(node, paragraph)
      node.location.start_line < line(paragraph.first) && line(paragraph.last) < node.location.end_line
    end

    def beneath(paragraph) = @source.statements.find { |node| node.location.start_line == line(paragraph.last) + 1 }

    # The statement a comment is in without being just above it or in a method, such as the class it floats in.
    def holding(paragraph)
      held = @source.statements.select { |node| @source.span(node).cover?(line(paragraph.first)..line(paragraph.last)) }
      held.min_by { |node| @source.span(node).size }
    end

    def definitions = @definitions ||= @source.nodes.select { |node| DEFINITIONS.include?(node.type) }

    def text(paragraph) = paragraph.map { |comment| comment.location.slice.delete_prefix("#").delete_prefix(" ") }.join("\n")

    # At most a class's worth of lines of the definition: all of it, or when it is longer, its first lines, or the lines
    # around the comment if the comment is further in.
    def code(node, comment)
      last = @source.span(node).end
      from = [node.location.start_line, [line(comment) - Source::LINES / 2, last - Source::LINES + 1].min].max
      @source.lines[from - 1, [last - from + 1, Source::LINES].min].join
    end

    def line(comment) = comment.location.start_line
  end
end
