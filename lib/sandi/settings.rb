# frozen_string_literal: true

require "yaml"
require_relative "errors"
require_relative "guideline"

module Sandi
  # .sandi.yml, where a project asks for more than the four rules: the guidelines it wants judged. Without one, none
  # are, and sandi calls no API.
  class Settings
    def initialize(path) = @path = path

    def guidelines = Array(settings["guidelines"]).map { |name| Guideline.named(name) }

    private

    def settings
      found = (YAML.safe_load_file(@path) if File.exist?(@path)) || {}
      found.is_a?(Hash) ? found : raise(Error, "#{@path} should name guidelines, as in guidelines: [WhatComment]")
    rescue Psych::SyntaxError => error
      raise Error, "#{@path} is not valid YAML: #{error.message}"
    end
  end
end
