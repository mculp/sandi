# frozen_string_literal: true

require_relative "comments"
require_relative "methods"

module Sandi
  # The places in the files RuboCop inspected that a guideline can be asked about, by the kind of place it reads: each
  # comment written for a reader, or each method. The files are read for a kind of place only when a guideline asks.
  class Places
    FINDERS = {"comment" => Comments, "method" => Methods}.freeze

    def initialize(paths, root:)
      @paths, @root, @found = paths, root, {}
    end

    def of(about) = @found[about] ||= @paths.flat_map { |path| FINDERS.fetch(about).of(path, root: @root) }
  end
end
