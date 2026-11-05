# frozen_string_literal: true

require_relative "test_helper"

# Sandi's guidelines: comments put to Jev, here a fake one on localhost, and counted in the same ratchet as the rules.
# A ratchet has to count the same tree the same way every time, so what decides a count, and what it costs, matters.
class GuidelinesTest < SandiCase
  COUNTER = <<~RUBY
    class Counter
      # Adds one to the count.
      def add
        @count += 1
      end
    end
  RUBY

  def judgments = JSON.parse(File.read(File.join(@root, ".sandi-judgments.json")))
  def asked = @jev.requests.map { |request| request.body.dig("state", "comment") }

  # A tree whose one comment Jev is asked about, with the WhatComment guideline on.
  def counter(yes:)
    guidelines("WhatComment")
    yes ? jev_says_yes_to("Adds one to the count.") : jev_says_yes_to
    write("lib/counter.rb", COUNTER)
    rubocop_reports("lib/counter.rb" => [])
  end

  def test_guidelines_are_off_unless_the_project_names_them
    jev_says_yes_to("Adds one to the count.")
    write("lib/counter.rb", COUNTER)
    record("lib/counter.rb" => [])
    assert_empty @jev.requests
    refute_includes @out, "guidelines"
    refute_includes baseline, "guidelines"
  end

  def test_a_comment_jev_says_yes_to_counts_against_its_file
    counter(yes: true)
    assert_equal 0, sandi("--update", "--allow-increase")
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
    assert_equal({"lib/counter.rb" => {"WhatComment" => 1}}, JSON.parse(baseline).dig("guidelines", "counts"))
  end

  def test_a_comment_counts_when_jev_is_at_least_70_percent_sure
    guidelines("WhatComment")
    jev { |state, _name| state["comment"] == "Seven." ? 0.7 : 0.69 }
    write("lib/numbers.rb", "# Seven.\ndef seven = 7\n\n# Six.\ndef six = 6\n")
    record("lib/numbers.rb" => [])
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
  end

  def test_a_new_comment_jev_says_yes_to_fails_and_is_pointed_to
    counter(yes: true)
    write("lib/counter.rb", COUNTER.sub("  # Adds one to the count.\n", ""))
    assert_equal 0, sandi("--update", "--allow-increase")
    write("lib/counter.rb", COUNTER)
    assert_equal 1, sandi
    assert_includes @out, "worse: lib/counter.rb WhatComment 0 -> 1"
    assert_includes @out, "lib/counter.rb:2 WhatComment 0.9"
  end

  def test_a_rerun_asks_jev_nothing_and_counts_what_it_said_before_even_if_it_would_now_say_otherwise
    counter(yes: true)
    assert_equal 1, sandi
    jev_says_yes_to
    assert_equal 1, sandi
    assert_empty @jev.requests
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
    assert_includes @out, "asked Jev nothing: all 1 answers were recorded"
  end

  def test_a_comment_is_asked_about_again_when_the_code_under_it_changes
    counter(yes: false)
    assert_equal 0, sandi
    @jev.requests.clear
    write("lib/counter.rb", COUNTER.sub("+= 1", "+= 2"))
    sandi
    assert_equal ["Adds one to the count."], asked
  end

  def test_only_the_comments_a_reader_reads_are_asked_about
    guidelines("WhatComment")
    jev_says_yes_to
    script("bin/tally", <<~RUBY)
      # frozen_string_literal: true
      # rubocop:disable Metrics/MethodLength

      # Loads what it needs.
      require "json"

      # A count of what a file breaks.
      class Tally
        # How many there may be.
        LIMIT = 4

        # Adds one to the total.
        def add
          # Bump the total.
          @total += 1 # by one
        end

        # Floats on its own.

        def total = @total
      end
    RUBY
    rubocop_reports("bin/tally" => [])
    sandi
    assert_equal ["A count of what a file breaks.", "Adds one to the total.", "Bump the total."], asked.sort
  end

  def test_jev_is_asked_with_the_key_the_pinned_model_and_the_comment_with_the_definition_it_documents
    counter(yes: false)
    sandi
    request = @jev.requests.first
    assert_equal "Bearer test-key", request.authorization
    assert_equal "typesafe/jev-1.14", request.body["model"]
    method = "  def add\n    @count += 1\n  end\n"
    assert_equal({"comment" => "Adds one to the count.", "code" => method}, request.body["state"])
    assert_equal "noul", request.body.dig("questions", "WhatComment", "type")
  end

  def test_a_comment_inside_a_method_is_asked_about_with_the_whole_method
    guidelines("WhatComment")
    jev_says_yes_to
    write("lib/total.rb", "def total(items)\n  # Add them up.\n  items.sum\nend\n")
    rubocop_reports("lib/total.rb" => [])
    sandi
    assert_equal "def total(items)\n  # Add them up.\n  items.sum\nend\n", @jev.requests.first.body.dig("state", "code")
  end

  def test_every_question_about_a_comment_goes_in_one_request_and_each_yes_counts
    guidelines("WhatComment", "StaleComment")
    jev_says_yes_to("Adds one to the count.")
    write("lib/counter.rb", COUNTER)
    rubocop_reports("lib/counter.rb" => [])
    sandi
    assert_equal [%w[StaleComment WhatComment]], @jev.requests.map { |request| request.body["questions"].keys.sort }
    assert_includes @out, "guidelines: 2 (StaleComment 1, WhatComment 1) in 1 of 1 files"
  end

  def test_without_a_key_the_recorded_answers_still_count
    counter(yes: true)
    assert_equal 0, sandi("--update", "--allow-increase")
    assert_equal 0, sandi(key: nil)
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
    refute_includes @out, "lib/counter.rb:2"
  end

  def test_more_comments_than_are_asked_at_once_are_all_asked
    guidelines("WhatComment")
    jev { 0.9 }
    write("lib/many.rb", (1..20).map { |number| "# Returns #{number}.\ndef number#{number} = #{number}\n" }.join("\n"))
    rubocop_reports("lib/many.rb" => [])
    sandi
    assert_equal 20, @jev.requests.size
    assert_includes @out, "guidelines: 20 (WhatComment 20) in 1 of 1 files"
  end

  def test_answers_jev_gave_before_it_failed_are_kept_for_the_next_run
    guidelines("WhatComment")
    jev(statuses: [200] * Sandi::Judge::AT_ONCE + [401]) { 0.1 }
    count = Sandi::Judge::AT_ONCE + 1
    write("lib/many.rb", (1..count).map { |number| "# Returns #{number}.\ndef number#{number} = #{number}\n" }.join("\n"))
    rubocop_reports("lib/many.rb" => [])
    assert_equal 2, sandi
    assert_equal Sandi::Judge::AT_ONCE, judgments.size
  end

  def test_an_answer_without_a_noul_means_sandi_could_not_count
    counter(yes: false)
    jev { nil }
    assert_equal 2, sandi
    assert_includes @err, "did not answer WhatComment"
  end

  def test_without_a_key_a_comment_not_yet_judged_leaves_the_baseline_as_it_is_and_says_why
    counter(yes: true)
    assert_equal 0, sandi("--update", "--allow-increase")
    before = baseline
    @jev.requests.clear
    write("lib/counter.rb", COUNTER.sub("Adds one", "Adds two"))
    assert_equal 0, sandi("--update", key: nil)
    assert_includes @out, "guidelines: not judged"
    assert_includes @out, "OPENROUTER_API_KEY"
    assert_equal before, baseline
    assert_empty @jev.requests
  end

  def test_a_key_jev_refuses_means_sandi_could_not_count
    counter(yes: false)
    jev(statuses: [401]) { 0.1 }
    assert_equal 2, sandi
    assert_includes @err, "401"
  end

  def test_a_busy_jev_is_asked_again
    counter(yes: false)
    jev(statuses: [529]) { 0.9 }
    assert_equal 1, sandi
    assert_equal 2, @jev.requests.size
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
  end

  def test_a_guideline_sandi_does_not_have_is_misuse_and_the_ones_it_has_are_named
    guidelines("WhatCommnet")
    rubocop_reports("lib/a.rb" => [])
    assert_equal 2, sandi
    assert_includes @err, "WhatCommnet"
    assert_includes @err, "WhatComment, StaleComment"
  end

  def test_a_check_keeps_answers_the_tree_no_longer_uses_and_an_update_drops_them
    counter(yes: false)
    assert_equal 0, sandi("--update")
    write("lib/counter.rb", COUNTER.sub("  # Adds one to the count.\n", ""))
    assert_equal 0, sandi
    assert_equal 1, judgments.size
    assert_equal 0, sandi("--update")
    assert_empty judgments
  end

  def test_the_summary_says_what_asking_jev_took
    counter(yes: false)
    sandi
    assert_includes @out, "asked Jev (typesafe/jev-1.14) through OpenRouter 1 of 1 questions"
    assert_includes @out, "120 input tokens"
  end
end
