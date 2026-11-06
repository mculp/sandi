# frozen_string_literal: true

require "prism"

module Sandi
  # A Ruby file, parsed once for the finders that read places in it, with what they share: its nodes, its comments and
  # the lines of its source.
  class Source
    # Jev judges worse as its state grows, so the code sent with a place stops after a class's worth of lines: code within
    # the first rule is sent whole, and a method that long breaks the second rule many times over.
    LINES = 100

    attr_reader :file

    def self.read(file, root:) = new(file, Prism.parse_file(File.join(root, file)))

    def initialize(file, parse)
      @file, @parse = file, parse
    end

    def comments = @parse.comments
    def magic_comments = @parse.magic_comments
    def nodes = @nodes ||= walk(@parse.value)
    def lines = @lines ||= @parse.source.source.lines

    private

    def walk(node) = [node, *node.compact_child_nodes.flat_map { |child| walk(child) }]
  end
end
