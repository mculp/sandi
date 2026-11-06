# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../lib/sandi"
require_relative "fake_jev"

# sandi against a tree in a temporary directory, a `rubocop` that reports what each test says and a Jev on localhost,
# so that these tests need no gems and make no network calls. The ratchet is what keeps the design limits from slipping
# back, so what it lets through matters.
class SandiCase < Minitest::Test
  def setup
    @root = Dir.mktmpdir("sandi-")
    @tools = File.join(@root, ".tools")
    FileUtils.mkdir_p(@tools)
  end

  def teardown
    @jev&.stop
    FileUtils.remove_entry(@root)
  end

  # What RuboCop will report: the cops that fired in each file it inspected, one name per offense. It only reports
  # files it read, so they exist.
  def rubocop_reports(offenses)
    offenses.each_key { |path| write(path, "") unless File.exist?(File.join(@root, path)) }
    files = offenses.map { |path, cops| {"path" => path, "offenses" => cops.map { |cop| {"cop_name" => "Metrics/#{cop}"} }} }
    report = JSON.generate("metadata" => {"rubocop_version" => "1.87.0"}, "files" => files)
    install("rubocop", "printf '%s' '#{report}'\nexit #{offenses.values.flatten.empty? ? 0 : 1}")
  end

  def install(name, script)
    File.write(File.join(@tools, name), "#!/bin/sh\n#{script}\n")
    File.chmod(0o755, File.join(@tools, name))
  end

  def write(path, body)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), body)
  end

  def script(path, body) = write(path, "#!/usr/bin/env ruby\n#{body}")

  # A .sandi.yml that turns on the guidelines named.
  def guidelines(*names) = write(".sandi.yml", "guidelines:\n#{names.map { |name| "  - #{name}\n" }.join}")

  # A file that sandi can read but not write.
  def read_only(path, body)
    skip "root can write a read-only file" if Process.uid.zero?
    write(path, body)
    File.chmod(0o444, File.join(@root, path))
  end

  # A Jev on localhost that answers each question with what the block gives for the state and the question's name. The
  # first answers can be HTTP errors instead, one per status given, or whole replies of the test's own, one per reply.
  def jev(statuses: [], replies: [], &noul)
    @jev&.stop
    @jev = FakeJev.new(statuses: statuses, replies: replies, &noul)
  end

  # A Jev that says yes (0.9) to every question about the comments given and no (0.1) to the rest.
  def jev_says_yes_to(*comments) = jev { |state, _name| comments.include?(state["comment"]) ? 0.9 : 0.1 }

  # The exit status of `sandi *argv` with only the fake tools on the PATH, only the fake Jev to ask, at `url`, and `key`
  # as the OpenRouter key, or none. Leaves what it said in @out and @err.
  def sandi(*argv, key: "test-key", url: jev_url)
    out, err = StringIO.new, StringIO.new
    status = with_env("PATH" => @tools, "OPENROUTER_API_KEY" => key, "SANDI_JEV_URL" => url) do
      Sandi::CLI.new(argv, root: @root, out: out, err: err).call
    end
    @out, @err = out.string, err.string
    status
  end

  # Nowhere, when the test started no Jev: a call fails rather than reach the real one.
  def jev_url = @jev ? @jev.url : "http://127.0.0.1:1/api/v1/systemone"

  # A nil value unsets the variable for the block.
  def with_env(variables)
    saved = variables.to_h { |name, _value| [name, ENV.fetch(name, nil)] }
    variables.each { |name, value| ENV[name] = value }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  # A baseline taken from a tree that looks like this.
  def record(offenses)
    rubocop_reports(offenses)
    assert_equal 0, sandi("--update", "--allow-increase")
  end

  def baseline = File.read(File.join(@root, ".sandi-baseline.json"))
end
