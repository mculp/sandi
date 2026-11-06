# frozen_string_literal: true

require "prism"

module Sandi
  # The methods in a file, each def with its own source, wherever it is defined: in a class or a module, in a block, in
  # `class << self`, at the top of a script, or on a line with other code.
  class Methods
    # A def is where it starts, by line and column, since two can share a line.
    Method = Data.define(:file, :line, :column, :code) do
      # What Jev reads to answer a question about the method.
      def state = {"method" => code}
    end
    # Jev judges worse as its state grows, so a method's source stops after a class's worth of lines, as a comment's
    # code does. A method that long breaks the second rule many times over.
    LINES = 100

    def self.of(file, root:) = new(file, Prism.parse_file(File.join(root, file))).to_a

    def initialize(file, parse)
      @file, @parse = file, parse
    end

    def to_a = defs.map { |node| Method.new(@file, node.location.start_line, node.location.start_column, code(node)) }

    private

    def defs = nodes(@parse.value).select { |node| node.type == :def_node }
    def nodes(node) = [node, *node.compact_child_nodes.flat_map { |child| nodes(child) }]

    # The def from its `def` to its `end`, as though it began its line: what shares a line with it is left out, and the
    # lines under it lose the indent of the line it starts on.
    def code(node)
      indent = node.location.start_line_slice[/\A\s*/]
      node.location.slice.lines.first(LINES).map { |line| line.delete_prefix(indent) }.join
    end
  end
end
