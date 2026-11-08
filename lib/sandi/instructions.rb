# frozen_string_literal: true

require "yaml"

module Sandi
  # What a code model is told before it is sent a file: the rules, then each guideline the project asks about with the
  # question it is judged by, what a yes and a no to it mean, and how to put a yes right where that is known. The words
  # are in config/autocorrect.yml.
  class Instructions
    WORDS = YAML.safe_load_file(File.expand_path("../../config/autocorrect.yml", __dir__))
    ANSWERS = {"true" => "Yes", "false" => "No"}.freeze

    def initialize(guidelines) = @chosen = guidelines

    def to_s = [WORDS.fetch("rules"), *guidelines, WORDS.fetch("how")].join("\n\n")

    private

    # The section on guidelines, or nothing when the project asks about none.
    def guidelines
      return [] if @chosen.empty?
      [WORDS.fetch("guidelines"), @chosen.map { |guideline| entry(guideline) }.join("\n")]
    end

    def entry(guideline)
      answers = guideline.criteria.map { |answer, meaning| "  #{ANSWERS.fetch(answer)}: #{meaning}" }
      ["- #{guideline.name}: #{guideline.instructions}", *answers, *fix(guideline)].join("\n")
    end

    def fix(guideline) = WORDS.fetch("fixes").slice(guideline.name).values.map { |how| "  To fix: #{how}" }
  end
end
