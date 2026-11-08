# frozen_string_literal: true

require_relative "tally"

module Sandi
  # Sandi's first three rules as RuboCop's Metrics cops count them: a class over 100 lines, a method over 5, a list of
  # more than 4 parameters.
  class Offenses
    def initialize(report) = @report = report

    def name = "offenses"
    def description = "RuboCop #{version}, the Metrics cops at the limits in .rubocop.yml, counting code lines"
    def paths = files.map { |file| file.fetch("path") }
    def tally = @tally ||= Tally.new(files.flat_map { |file| cops_in(file) }.tally)

    def summary = "offenses: #{tally.summary(paths.size)}"

    # What RuboCop says is wrong in a file, a line for each offense: "line 12: MethodLength: Method has too many lines.
    # [7/5]".
    def problems(path)
      found = files.find { |file| file.fetch("path") == path }
      Array(found&.fetch("offenses")).map { |offense| problem(offense) }
    end

    private

    def problem(offense)
      cop = offense.fetch("cop_name").delete_prefix("Metrics/")
      "line #{offense.dig("location", "start_line")}: #{cop}: #{offense.fetch("message")}"
    end

    def files = @report.fetch("files")
    def version = @report.dig("metadata", "rubocop_version")

    # One [file, cop] per offense, for Array#tally.
    def cops_in(file)
      file.fetch("offenses").map { |offense| [file.fetch("path"), offense.fetch("cop_name").delete_prefix("Metrics/")] }
    end
  end
end
