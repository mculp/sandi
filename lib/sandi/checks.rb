# frozen_string_literal: true

require "open3"
require "prism"
require_relative "source"

module Sandi
  # What a rewrite of a file must survive before it is kept: the file measured again, where its counts must fall and
  # none may rise, every method it defined still defined, and the project's tests, which must pass. It measures with
  # the rules' own counters, the ones the ratchet reads, so a rewrite is judged as the ratchet will judge it.
  class Checks
    # How many lines of a failing test run the model is shown.
    TAIL = 40

    # `rules` builds the counters afresh, since they read the files as they are. `tests` is a command for the shell.
    def initialize(root, rules, tests)
      @root, @rules, @tests = root, rules, tests
    end

    def offending = counters.flat_map { |rule| rule.tally.keys.map(&:first) }.uniq.sort
    def problems(path) = counters.flat_map { |rule| rule.problems(path) }
    def counts(path) = counters.map { |rule| rule.tally.of(path) }.reduce({}, :merge)
    def read(path) = File.read(File.join(@root, path))

    def write(path, text)
      File.write(File.join(@root, path), text)
      @counters = nil
    end

    # Why a rewrite is rejected, or nil when it takes offenses away, adds none of another kind, loses no method and
    # leaves the tests passing. `original` is the file's source before the rewrite.
    def verdict(path, before, original)
      after = counts(path)
      rose(before, after) || still(before, after) || lost(original, read(path)) || failing_tests
    end

    private

    def counters = @counters ||= @rules.call

    def rose(before, after)
      names = after.select { |name, count| count > before.fetch(name, 0) }
      names.map { |name, count| "#{name} rose from #{before.fetch(name, 0)} to #{count}" }.join(", ") unless names.empty?
    end

    def still(before, after)
      return if after.values.sum < before.values.sum
      "it still has #{plural(after.values.sum)}, and it had #{before.values.sum}"
    end

    def plural(count) = "#{count} offense#{"s" unless count == 1}"

    # Tests that pass prove little if the rewrite deleted the failing ones, so every method must still be defined.
    def lost(original, rewrite)
      now = defined_in(rewrite)
      gone = defined_in(original).select { |name, count| now.fetch(name, 0) < count }.keys
      "it no longer defines #{gone.join(", ")}" unless gone.empty?
    end

    # The methods a source defines, counted by name.
    def defined_in(source)
      Source.new("", Prism.parse(source)).nodes.select { |node| node.type == :def_node }.map(&:name).tally
    end

    def failing_tests
      output, status = Open3.capture2e("/bin/sh", "-c", @tests, chdir: @root)
      "the tests failed:\n#{output.lines.last(TAIL).join}" unless status.success?
    end
  end
end
