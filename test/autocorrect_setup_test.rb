# frozen_string_literal: true

require_relative "autocorrect_helper"
require_relative "test_helper"

# What `sandi --autocorrect` needs before it will ask a model anything, which model it asks, and what it says it cost.
class AutocorrectSetupTest < SandiCase
  include AutocorrectHelper

  def test_it_will_not_start_without_a_command_that_runs_the_projects_tests
    project(SLOW, "guidelines: []\n")
    assert_equal 2, sandi("--autocorrect")
    assert_includes @err, "autocorrect needs a test command"
  end

  def test_it_will_not_start_without_a_key
    project
    model { fenced(QUICK) }
    assert_equal 2, sandi("--autocorrect", key: nil)
    assert_includes @err, "OPENROUTER_API_KEY"
    assert_empty @model.requests
  end

  def test_a_key_the_model_refuses_stops_it_and_leaves_the_file_alone
    project
    model(statuses: [401]) { fenced(QUICK) }
    assert_equal 2, sandi("--autocorrect")
    assert_equal SLOW, read("lib/a.rb")
    assert_includes @err, "answered 401"
  end

  def test_with_nothing_over_a_limit_nothing_is_asked
    assert_equal 0, autocorrect(QUICK) { fenced(QUICK) }
    assert_empty @model.requests
    assert_includes @out, "autocorrect: no file counts against a rule"
  end

  def test_the_default_model_is_haiku_and_the_request_asks_for_nothing_it_lacks
    autocorrect { fenced(QUICK) }
    sent = @model.requests.first
    assert_equal ["anthropic/claude-haiku-5.5", "Bearer test-key"], [sent.body["model"], sent.authorization]
    refute_includes sent.body.keys, "temperature"
    assert_equal({"include" => true}, sent.body["usage"])
  end

  def test_the_model_asked_is_the_one_the_project_names
    autocorrect(sandi_yml: "#{TESTED}  model: openai/gpt-6.1-terra\n") { fenced(QUICK) }
    assert_equal "openai/gpt-6.1-terra", @model.requests.first.body["model"]
  end

  def test_it_says_what_asking_cost
    autocorrect { fenced(QUICK) }
    cost = "asked anthropic/claude-haiku-5.5 through OpenRouter 1 request: " \
           "1000 input tokens, 500 output tokens, about $0.0100"
    assert_includes @out, cost
  end

  def test_with_the_projects_own_provider_key_it_counts_what_the_provider_charged
    project
    model(replies: [own_key_reply(0.02)])
    sandi("--autocorrect")
    assert_includes @out, "about $0.0200"
  end

  def test_it_writes_its_progress_as_it_goes_so_that_a_redirected_run_shows_it
    File.open(File::NULL, "w") do |out|
      Sandi::Autocorrect.new([], nil, out)
      assert_predicate out, :sync
    end
  end

  def test_the_usage_names_the_flag
    assert_equal 2, sandi("--bogus")
    assert_includes @err, "--autocorrect"
  end
end
