# frozen_string_literal: true

require_relative "comments"
require_relative "methods"
require_relative "source"

module Sandi
  # The places in the files RuboCop inspected that a guideline can be asked about, by the kind of place it reads: each
  # comment written for a reader, or each method. The files are read for a kind of place only when a guideline asks, and
  # each is parsed once, however many kinds of place ask.
  class Places
    FINDERS = {"comment" => Comments, "method" => Methods}.freeze

    def initialize(paths, root:)
      @paths, @root, @found = paths, root, {}
    end

    def of(about) = @found[about] ||= sources.flat_map { |source| FINDERS.fetch(about).new(source).to_a }

    private

    def sources = @sources ||= @paths.map { |path| Source.read(path, root: @root) }
  end
end
