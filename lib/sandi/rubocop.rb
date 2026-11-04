# frozen_string_literal: true

require "json"
require "open3"
require_relative "errors"

module Sandi
  # RuboCop run over what the project's .rubocop.yml includes. The one place that knows it is a program on the PATH, which
  # under `bundle exec` is the project's own.
  class Rubocop
    # The version sandi is tested against. A baseline's counts are one version's, so a project pins RuboCop where it
    # pins its other gems, and the baseline records which version it was.
    VERSION = "1.87.0"
    INSTALL = "add rubocop to the Gemfile, or gem install rubocop -v #{VERSION} --no-document"

    def initialize(root, command: "rubocop")
      @root, @command = root, command
    end

    # RuboCop's JSON report. It exits 1 when it finds offenses, which is what this exists to count.
    def report
      out, err, status = Open3.capture3(@command, "--format", "json", "--cache", "false", chdir: @root)
      return JSON.parse(out) if [0, 1].include?(status.exitstatus)
      raise Error, "rubocop exited #{status.exitstatus}: #{err.strip}"
    rescue Errno::ENOENT
      raise Error, "rubocop is not installed. Install it with: #{INSTALL}"
    end
  end
end
