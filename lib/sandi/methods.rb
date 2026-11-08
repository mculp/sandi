# frozen_string_literal: true

require_relative "source"

module Sandi
  # The methods in a file, each def and each block given to define_method with its own source, wherever it is defined:
  # in a class or a module, in a block, in `class << self`, at the top of a script, or on a line with other code.
  class Methods
    # A method is where it starts, by line and column, since two can share a line.
    Method = Data.define(:file, :line, :column, :code) do
      # What Jev reads to answer a question about the method.
      def state = {"method" => code}

      # How a message points at the method, beside its line.
      def first_line = code[/.*/].strip
    end

    def initialize(source)
      @source = source
    end

    def to_a = @source.method_nodes.map { |node| place(node) }

    private

    def place(node) = Method.new(@source.file, node.location.start_line, node.location.start_column, code(node))

    # The def from its `def` to its `end`, as though it began its line: what shares a line with it is left out, and the
    # lines under it lose the indent of the line it starts on. A def longer than a class's worth of lines stops there.
    def code(node)
      indent = node.location.start_line_slice[/\A\s*/]
      node.location.slice.lines.first(Source::LINES).map { |line| line.delete_prefix(indent) }.join
    end
  end
end
