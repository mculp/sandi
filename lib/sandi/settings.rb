# frozen_string_literal: true

require "yaml"
require_relative "errors"
require_relative "guideline"
require_relative "rewriter"

module Sandi
  # .sandi.yml, where a project asks for more than the four rules: the guidelines it wants judged, and how autocorrect
  # is to work. Without one, no guideline is judged, and sandi calls no API unless it is asked to autocorrect.
  class Settings
    # How autocorrect works here: the command whose success keeps a rewrite, and the models to ask, in the order to ask.
    Autocorrection = Data.define(:test, :models)

    def initialize(path) = @path = path

    def guidelines = Array(settings["guidelines"]).map { |name| Guideline.named(name) }

    def autocorrect
      found = settings.fetch("autocorrect", {})
      raise Error, "#{@path} should say how to autocorrect, as in autocorrect: {test: rake}" unless found.is_a?(Hash)
      Autocorrection.new(found["test"], Array(found["model"] || Rewriter::MODEL))
    end

    private

    def settings
      found = (YAML.safe_load_file(@path) if File.exist?(@path)) || {}
      found.is_a?(Hash) ? found : raise(Error, "#{@path} should name guidelines, as in guidelines: [WhatComment]")
    rescue Psych::SyntaxError => error
      raise Error, "#{@path} is not valid YAML: #{error.message}"
    end
  end
end
