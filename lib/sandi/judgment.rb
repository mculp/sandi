# frozen_string_literal: true

require "digest"
require "json"

module Sandi
  # A guideline asked of a comment. Its answer is recorded under a digest of everything the answer depends on, so that
  # it is used again for the same comment, code, question and model, and for nothing else.
  Judgment = Data.define(:comment, :guideline) do
    def file = comment.file
    def name = guideline.name
    # Where a yes is counted: against its file, under the guideline's name.
    def counts_against = [file, name]
    def question = guideline.question
    def state = {"comment" => comment.text, "code" => comment.code}
    def key(model) = Digest::SHA256.hexdigest(JSON.generate([model, question, state]))
  end
end
