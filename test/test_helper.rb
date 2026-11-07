# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../lib/sandi"
require_relative "fake_jev"
require_relative "fake_model"

# sandi against a tree in a temporary directory, a `rubocop` that reports what each test says, and a Jev and a code
# model on localhost, so that these tests need no gems and make no network calls. The ratchet is what keeps the design
# limits from slipping back, so what it lets through matters.
class SandiCase < Minitest::Test
  def setup
    @root = Dir.mktmpdir("sandi-")
    @tools = File.join(@root, ".tools")
    FileUtils.mkdir_p(@tools)
  end

  def teardown
    @jev&.stop
    @model&.stop
    FileUtils.remove_entry(@root)
  end

  # Installs a `rubocop` that reports the cops that fired in each file, one name per offense. RuboCop only reports
  # files it read, so each file is created, empty, unless the test has written it.
  def rubocop_reports(offenses)
    offenses.each_key { |path| write(path, "") unless File.exist?(File.join(@root, path)) }
    files = offenses.map { |path, cops| {"path" => path, "offenses" => cops.map { |cop| {"cop_name" => "Metrics/#{cop}"} }} }
    report = JSON.generate("metadata" => {"rubocop_version" => "1.87.0"}, "files" => files)
    install("rubocop", "printf '%s' '#{report}'\nexit #{offenses.values.flatten.empty? ? 0 : 1}")
  end

  # A tool on the PATH: a shell script, or a script for the interpreter `shell` names.
  def install(name, script, shell: "/bin/sh")
    File.write(File.join(@tools, name), "#!#{shell}\n#{script}\n")
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

  # A code model on localhost that answers each request with what the block gives for it. The first answers can be HTTP
  # errors instead, one per status given, or whole replies of the test's own, one per reply.
  def model(statuses: [], replies: [], &content)
    @model&.stop
    @model = FakeModel.new(statuses: statuses, replies: replies, &content)
  end

  # The exit status of `sandi *argv` with only the fake tools on the PATH, only the fake Jev and the fake model to ask,
  # the Jev at `url`, and `key` as the OpenRouter key, or none. Leaves what it said in @out and @err.
  def sandi(*argv, key: "test-key", url: jev_url)
    out, err = StringIO.new, StringIO.new
    status = with_env(sandi_env(key, url)) { Sandi::CLI.new(argv, root: @root, out: out, err: err).call }
    @out, @err = out.string, err.string
    status
  end

  # The environment `sandi` runs in: the fake tools and nothing else on the PATH, and the fake services to ask.
  def sandi_env(key, url)
    {"PATH" => @tools, "OPENROUTER_API_KEY" => key, "SANDI_JEV_URL" => url, "SANDI_AUTOCORRECT_URL" => model_url}
  end

  # Nowhere, when the test started no Jev: a call fails rather than reach the real one.
  def jev_url = @jev ? @jev.url : "http://127.0.0.1:1/api/v1/systemone"
  def model_url = @model ? @model.url : "http://127.0.0.1:1/api/v1/chat/completions"

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
