# frozen_string_literal: true

require_relative "lib/sandi/version"

Gem::Specification.new do |spec|
  spec.name = "sandi"
  spec.version = Sandi::VERSION
  spec.authors = ["Matt Culpepper"]
  spec.summary = "A ratchet on Sandi Metz's four rules"
  spec.description = "Counts what breaks Sandi Metz's rules with RuboCop and Prism, holds the counts against a " \
                     "committed baseline that may fall and never rise, and fails when one rises."
  spec.homepage = "https://github.com/mculp/sandi"
  spec.required_ruby_version = ">= 3.3"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "exe/*", "config/*.yml", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["sandi"]

  # RuboCop does the counting for rules 1-3 and runs as a program, so the project's Gemfile picks its version.
  spec.add_dependency "rubocop", "~> 1.87"
end
