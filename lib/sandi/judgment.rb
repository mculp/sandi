# frozen_string_literal: true

require "digest"
require "json"

module Sandi
  # A guideline asked of a place in the code, a comment or a method. Its answer is recorded under a digest of everything
  # the answer depends on, so that it is used again for the same state, question and model, and for nothing else. No
  # state holds a line number, so a place that only moves keeps its answer.
  Judgment = Data.define(:place, :guideline) do
    def file = place.file
    def line = place.line
    def name = guideline.name
    # Where a yes is counted: against its file, under the guideline's name.
    def counts_against = [file, name]
    def question = guideline.question
    def state = place.state
    def key(model) = Digest::SHA256.hexdigest(JSON.generate([model, question, state]))
  end
end
