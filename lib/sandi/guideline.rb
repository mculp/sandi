# frozen_string_literal: true

require "yaml"
require_relative "errors"

module Sandi
  # Something Sandi Metz says about code that no parser can check, put to a decision model as a yes/no question about
  # one place in the code: a comment and the code it is about, or a method. The questions are in config/guidelines.yml,
  # beside the rules' limits.
  class Guideline
    CATALOG = File.expand_path("../../config/guidelines.yml", __dir__)

    def self.all = @all ||= YAML.safe_load_file(CATALOG).map { |name, entry| new(name, entry) }

    def self.named(name)
      all.find { |guideline| guideline.name == name } ||
        raise(Error, "sandi has no guideline #{name}. It has #{all.map(&:name).join(", ")}")
    end

    attr_reader :name, :abouts

    # An entry says what kinds of place its guideline is about, one or a list, a comment unless it names others. That is
    # not part of the question, so it isn't sent to Jev or digested into the key of an answer.
    def initialize(name, entry)
      @name, @abouts, @question = name, Array(entry.fetch("about", "comment")), entry.except("about")
    end

    # A noul question: Jev answers it with the probability that the answer is yes.
    def question = {"type" => "noul"}.merge(@question)

    # The question in words, which a yes answers.
    def instructions = @question.fetch("instructions")

    # What a yes and a no to the question mean, as {"true" => ..., "false" => ...}.
    def criteria = @question.fetch("criteria")
  end
end
