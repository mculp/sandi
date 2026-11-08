# frozen_string_literal: true

require "prism"

module Sandi
  # A Ruby file, parsed once for the finders that read places in it, with what they share: its nodes, its statements,
  # its comments and the lines of its source.
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

    # Every node that stands alone in a body: of the file, a class, a method, a block, an if, and so on.
    def statements = @statements ||= nodes.select { |node| node.type == :statements_node }.flat_map(&:body)

    # The lines a node is on, with the text of a heredoc in it, which comes after the line that opens the heredoc and so
    # past where the node's own location ends.
    def span(node) = node.location.start_line..[node.location.end_line, *heredoc_ends(node)].max

    private

    def walk(node) = [node, *node.compact_child_nodes.flat_map { |child| walk(child) }]

    def heredoc_ends(node)
      inside = heredocs.select { |heredoc| offsets(node).cover?(offsets(heredoc)) }
      inside.map { |heredoc| heredoc.closing_loc.start_line }
    end

    def heredocs = @heredocs ||= nodes.select { |node| node.respond_to?(:heredoc?) && node.heredoc? }
    def offsets(node) = node.location.start_offset...node.location.end_offset
  end
end
