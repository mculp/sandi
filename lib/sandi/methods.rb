# frozen_string_literal: true

require "prism"

module Sandi
  # The methods in a file, each def with its source, wherever it is defined: in a class or a module, in a block, in
  # `class << self` or at the top of a script.
  class Methods
    Method = Data.define(:file, :line, :code) do
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

    def to_a = defs.map { |node| Method.new(@file, node.location.start_line, code(node)) }

    private

    def defs = nodes(@parse.value).select { |node| node.type == :def_node }
    def nodes(node) = [node, *node.compact_child_nodes.flat_map { |child| nodes(child) }]

    def code(node) = source[node.location.start_line - 1, [length(node), LINES].min].join
    def length(node) = node.location.end_line - node.location.start_line + 1
    def source = @source ||= @parse.source.source.lines
  end
end
