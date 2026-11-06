# frozen_string_literal: true

require "yaml"
require_relative "errors"

module Sandi
  # Something Sandi Metz says about code that no parser can check, put to a decision model as a yes/no question about
  # a comment and the code it is about. The questions are in config/guidelines.yml, beside the rules' limits.
  class Guideline
    CATALOG = File.expand_path("../../config/guidelines.yml", __dir__)

    def self.all = @all ||= YAML.safe_load_file(CATALOG).map { |name, question| new(name, question) }

    def self.named(name)
      all.find { |guideline| guideline.name == name } ||
        raise(Error, "sandi has no guideline #{name}. It has #{all.map(&:name).join(", ")}")
    end

    attr_reader :name

    def initialize(name, question)
      @name, @question = name, question
    end

    # A noul question: Jev answers it with the probability that the answer is yes.
    def question = {"type" => "noul"}.merge(@question)
  end
end
