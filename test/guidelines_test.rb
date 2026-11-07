# frozen_string_literal: true

require "minitest/mock"
require_relative "test_helper"

# Sandi's guidelines: comments put to Jev, here a fake one on localhost, and counted in the same ratchet as the rules.
# A ratchet has to count the same tree the same way every time, so what decides a count, and what it costs, matters.
module GuidelinesFixtures
  COUNTER = <<~RUBY
    class Counter
      # Adds one to the count.
      def add
        @count += 1
      end
    end
  RUBY

  ADD_METHOD = "  def add\n    @count += 1\n  end\n"

  DECLINES_TWO = proc { |state, _name| state["comment"] == "Returns 2." ? nil : 0.1 }

  TALLY = <<~RUBY
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

  CART = <<~RUBY
    class Cart
      # rubocop:disable Metrics/AbcSize
      # Sums the cart, before tax.
      # rubocop:disable Metrics/MethodLength
      def total = @items.sum(&:price)

      # rubocop:disable Metrics/AbcSize
      def count = @items.size
    end
  RUBY
end

module GuidelinesSupport
  include GuidelinesFixtures

  def judgments = JSON.parse(File.read(File.join(@root, ".sandi-judgments.json")))
  def asked = @jev.requests.map { |request| request.body.dig("state", "comment") }

  def asked_code = @jev.requests.first.body.dig("state", "code")

  # A tree whose one comment Jev is asked about, with the WhatComment guideline on.
  def counter(yes:)
    guidelines("WhatComment")
    yes ? jev_says_yes_to("Adds one to the count.") : jev_says_yes_to
    write("lib/counter.rb", COUNTER)
    rubocop_reports("lib/counter.rb" => [])
  end

  def counter_judged_by(*names)
    guidelines(*names)
    jev_says_yes_to("Adds one to the count.")
    write("lib/counter.rb", COUNTER)
    rubocop_reports("lib/counter.rb" => [])
  end

  def unnamed_counter
    jev_says_yes_to("Adds one to the count.")
    write("lib/counter.rb", COUNTER)
    record("lib/counter.rb" => [])
  end

  def uncomment_counter
    write("lib/counter.rb", COUNTER.sub("  # Adds one to the count.\n", ""))
  end

  def learn_then_uncomment
    counter(yes: true)
    uncomment_counter
    assert_equal 0, sandi("--update", "--allow-increase")
  end

  def counter_then_uncommented
    counter(yes: false)
    assert_equal 0, sandi("--update")
    uncomment_counter
  end

  def counted_once
    counter(yes: true)
    assert_equal 1, sandi
  end

  def first_request
    counter(yes: false)
    sandi
    @jev.requests.first
  end

  # A file of methods, each under a comment that says what it returns: "Returns 1." and so on.
  def numbers(count)
    methods = (1..count).map { |number| "# Returns #{number}.\ndef number#{number} = #{number}\n" }
    write("lib/many.rb", methods.join("\n"))
    rubocop_reports("lib/many.rb" => [])
  end

  def judge_numbers(count, &answer)
    guidelines("WhatComment")
    jev(&answer)
    numbers(count)
  end

  # A method of `length` lines with the comment "Totals the cart." on its own line, the one at `at`.
  def long_method(length:, at:)
    lines = Array.new(length - 2) { |index| "  total += #{index + 1}\n" }
    lines[at - 2] = "  # Totals the cart.\n"
    write("lib/long.rb", ["def long\n", *lines, "end\n"].join)
    rubocop_reports("lib/long.rb" => [])
  end

  def long_method_asked(at:)
    guidelines("WhatComment")
    jev_says_yes_to("Totals the cart.")
    long_method(length: 153, at: at)
    sandi
  end

  def edit_counter(from, to)
    @jev.requests.clear
    write("lib/counter.rb", COUNTER.sub(from, to))
  end

  def learned_then_edited
    counter(yes: true)
    assert_equal 0, sandi("--update", "--allow-increase")
    before = baseline
    edit_counter("Adds one", "Adds two")
    before
  end

  def tally_script
    script("bin/tally", TALLY)
    rubocop_reports("bin/tally" => [])
  end

  def judged_tree(path, source)
    guidelines("WhatComment")
    jev_says_yes_to
    write(path, source)
    rubocop_reports(path => [])
  end

  def cart_asked
    guidelines("WhatComment")
    jev_says_yes_to("Sums the cart, before tax.")
    write("lib/cart.rb", CART)
    rubocop_reports("lib/cart.rb" => [])
  end
end

class GuidelinesTest < SandiCase
  include GuidelinesSupport

  def counted_then_jev_changes_its_mind
    counted_once
    jev_says_yes_to
  end

  def test_guidelines_are_off_unless_the_project_names_them
    unnamed_counter
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
    learn_then_uncomment
    write("lib/counter.rb", COUNTER)
    assert_equal 1, sandi
    assert_includes @out, "worse: lib/counter.rb WhatComment 0 -> 1"
    assert_includes @out, "lib/counter.rb:2 WhatComment 0.9"
  end

  def test_a_rerun_asks_jev_nothing_and_counts_what_it_said_before_even_if_it_would_now_say_otherwise
    counted_then_jev_changes_its_mind
    assert_equal 1, sandi
    assert_empty @jev.requests
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
    assert_includes @out, "asked Jev nothing: all 1 answers were recorded"
  end

  def test_a_comment_is_asked_about_again_when_the_code_under_it_changes
    counter(yes: false)
    assert_equal 0, sandi
    edit_counter("+= 1", "+= 2")
    sandi
    assert_equal ["Adds one to the count."], asked
  end

  def test_without_a_key_the_recorded_answers_still_count
    counter(yes: true)
    assert_equal 0, sandi("--update", "--allow-increase")
    assert_equal 0, sandi(key: nil)
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
    refute_includes @out, "lib/counter.rb:2"
  end

  def test_the_summary_says_what_asking_jev_took
    counter(yes: false)
    sandi
    assert_includes @out, "asked Jev (typesafe/jev-1.14) through OpenRouter 1 of 1 questions"
    assert_includes @out, "120 input tokens"
  end
end

class GuidelinesReadingTest < SandiCase
  include GuidelinesSupport

  def test_only_the_comments_a_reader_reads_are_asked_about
    guidelines("WhatComment")
    jev_says_yes_to
    tally_script
    sandi
    assert_equal ["A count of what a file breaks.", "Adds one to the total.", "Bump the total."], asked.sort
  end

  def test_a_directive_beside_a_comment_is_left_out_of_it_but_does_not_separate_it_from_its_def
    cart_asked
    assert_equal 1, sandi
    state = {"comment" => "Sums the cart, before tax.", "code" => "  def total = @items.sum(&:price)\n"}
    assert_equal [state], @jev.requests.map { |request| request.body["state"] }
    assert_includes @out, "lib/cart.rb:3 WhatComment 0.9"
  end

  def test_a_comment_deep_in_a_long_method_is_asked_with_the_lines_around_it
    long_method_asked(at: 122)
    code = asked_code
    assert_includes code, "# Totals the cart."
    assert_equal Sandi::Source::LINES, code.lines.size
  end

  def test_a_comment_near_the_end_of_a_long_method_is_asked_with_its_last_lines
    long_method_asked(at: 150)
    code = asked_code
    assert_includes code, "# Totals the cart."
    assert_equal "end\n", code.lines.last
    assert_equal Sandi::Source::LINES, code.lines.size
  end

  def test_a_comment_near_the_top_of_a_long_method_is_asked_with_its_first_lines
    long_method_asked(at: 5)
    code = asked_code
    assert_equal "def long\n", code.lines.first
    assert_includes code, "# Totals the cart."
    assert_equal Sandi::Source::LINES, code.lines.size
  end

  def test_jev_is_asked_with_the_key_the_pinned_model_and_the_comment_with_the_definition_it_documents
    request = first_request
    assert_equal "Bearer test-key", request.authorization
    assert_equal "typesafe/jev-1.14", request.body["model"]
    assert_equal({"comment" => "Adds one to the count.", "code" => ADD_METHOD}, request.body["state"])
    assert_equal "noul", request.body.dig("questions", "WhatComment", "type")
  end

  def test_a_comment_inside_a_method_is_asked_about_with_the_whole_method
    judged_tree("lib/total.rb", "def total(items)\n  # Add them up.\n  items.sum\nend\n")
    sandi
    assert_equal "def total(items)\n  # Add them up.\n  items.sum\nend\n", @jev.requests.first.body.dig("state", "code")
  end

  def test_every_question_about_a_comment_goes_in_one_request_and_each_yes_counts
    counter_judged_by("WhatComment", "StaleComment")
    sandi
    assert_equal [%w[StaleComment WhatComment]], @jev.requests.map { |request| request.body["questions"].keys.sort }
    assert_includes @out, "guidelines: 2 (StaleComment 1, WhatComment 1) in 1 of 1 files"
  end
end

class GuidelinesFailureTest < SandiCase
  include GuidelinesSupport

  def test_more_comments_than_are_asked_at_once_are_all_asked
    judge_numbers(20) { 0.9 }
    sandi
    assert_equal 20, @jev.requests.size
    assert_includes @out, "guidelines: 20 (WhatComment 20) in 1 of 1 files"
  end

  def test_the_key_of_each_judgment_is_worked_out_once
    judge_numbers(3) { 0.1 }
    digests = 0
    real = Digest::SHA256.method(:hexdigest)
    Digest::SHA256.stub(:hexdigest, ->(text) { digests += 1; real.call(text) }) { sandi }
    assert_equal 3, digests
  end

  def test_answers_jev_gave_before_it_failed_are_kept_for_the_next_run
    guidelines("WhatComment")
    jev(statuses: [200] * Sandi::Judge::AT_ONCE + [401]) { 0.1 }
    numbers(Sandi::Judge::AT_ONCE + 1)
    assert_equal 2, sandi
    assert_equal Sandi::Judge::AT_ONCE, judgments.size
  end

  def test_answers_to_the_other_requests_asked_at_once_are_kept_when_one_fails
    judge_numbers(3, &DECLINES_TWO)
    assert_equal 2, sandi
    assert_equal 2, judgments.size
  end

  def test_answers_sandi_cannot_save_mean_it_could_not_count
    counter(yes: false)
    read_only(".sandi-judgments.json", "{}\n")
    assert_equal 2, sandi
    assert_includes @err, ".sandi-judgments.json"
  end

  def test_when_asking_fails_and_saving_fails_too_the_failure_to_ask_is_the_one_reported
    judge_numbers(2, &DECLINES_TWO)
    read_only(".sandi-judgments.json", "{}\n")
    assert_equal 2, sandi
    assert_includes @err, "did not answer WhatComment"
  end

  def test_an_answer_without_a_noul_means_sandi_could_not_count
    counter(yes: false)
    jev { nil }
    assert_equal 2, sandi
    assert_includes @err, "did not answer WhatComment"
  end

  def test_a_noul_that_is_not_a_number_means_sandi_could_not_count
    counter(yes: false)
    jev { "0.9" }
    assert_equal 2, sandi
    assert_includes @err, "did not answer WhatComment"
  end

  def test_a_reply_that_is_not_a_json_object_means_sandi_could_not_count
    counter(yes: false)
    jev(replies: [nil]) { 0.1 }
    assert_equal 2, sandi
    assert_includes @err, "answered in a way sandi can't read"
  end

  def test_a_reply_that_is_not_http_means_sandi_could_not_count
    counter(yes: false)
    jev(statuses: ["???"]) { 0.1 }
    assert_equal 2, sandi
    assert_includes @err, "answered in a way sandi can't read"
  end
end

class GuidelinesAskingTest < SandiCase
  include GuidelinesSupport

  def assert_not_judged
    assert_includes @out, "guidelines: not judged"
    assert_includes @out, "OPENROUTER_API_KEY"
  end

  def test_a_jev_url_without_a_path_is_asked_at_its_root
    counter(yes: true)
    assert_equal 1, sandi(url: @jev.url.delete_suffix("/api/v1/systemone"))
    assert_includes @out, "guidelines: 1 (WhatComment 1) in 1 of 1 files"
  end

  def test_without_a_key_a_comment_not_yet_judged_leaves_the_baseline_as_it_is_and_says_why
    before = learned_then_edited
    assert_equal 0, sandi("--update", key: nil)
    assert_not_judged
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
    counter_then_uncommented
    assert_equal 0, sandi
    assert_equal 1, judgments.size
    assert_equal 0, sandi("--update")
    assert_empty judgments
  end
end
