# frozen_string_literal: true

require_relative "autocorrect_helper"
require_relative "test_helper"

# A guideline is a judgment, and a rewrite can break one while it fixes a rule. So autocorrect puts a rewrite to the
# same Jev that judged the file, here a fake one on localhost, and keeps it only if the file's count falls.
class AutocorrectGuidelinesTest < SandiCase
  include AutocorrectHelper

  def test_a_comment_a_guideline_flags_is_rewritten_and_the_rewrite_kept_when_that_clears_it
    assert_equal 0, guided { fenced(QUICK) }
    assert_equal QUICK, read("lib/a.rb")
    assert_includes @out, "autocorrect: lib/a.rb WhatComment 1"
    assert_includes @out, "autocorrect: fixed 1 of 1 files"
  end

  def test_the_model_is_told_which_comment_was_found_and_what_was_asked_of_it
    guided { fenced(QUICK) }
    question = Sandi::Guideline.named("WhatComment").instructions
    assert_includes asked.first, "line 2: WhatComment: \"add one\": #{question}"
  end

  def test_the_model_is_told_each_guideline_the_project_asks_about_and_what_a_yes_and_a_no_to_it_mean
    guided { fenced(QUICK) }
    assert_includes told, "- WhatComment: Is `comment` a note inside a method in `code` that only says what the lines"
    assert_includes told, "  Yes: The comment is a line inside a method in `code`"
    assert_includes told, "  No: The comment is not inside a method in `code`"
  end

  def test_the_model_is_told_how_to_put_a_yes_right_where_the_guideline_says
    guided { fenced(QUICK) }
    assert_includes told, "  To fix: Extract the lines the comment describes into a method named for what it says"
  end

  def test_the_model_is_told_the_guidelines_in_the_order_the_project_names_them_and_no_others
    jev_says_yes_to("add one")
    autocorrect(sandi_yml: "guidelines: [StaleComment, WhatComment]\n#{TESTED}") { fenced(QUICK) }
    assert_operator told.index("- StaleComment:"), :<, told.index("- WhatComment:")
    refute_includes told, "- Demeter:"
  end

  def test_what_was_found_is_listed_in_the_order_of_the_file_not_of_the_guidelines
    found = {"add one" => "WhatComment", "add two" => "StaleComment"}
    jev { |state, name| found[state["comment"]] == name ? 0.9 : 0.1 }
    autocorrect(TWO_NARRATED, sandi_yml: "guidelines: [StaleComment, WhatComment]\n#{TESTED}") { fenced(QUICK) }
    order = ['line 2: WhatComment: "add one"', 'line 4: StaleComment: "add two"'].map { |line| asked.first.index(line) }
    assert_equal order.sort, order
  end

  def test_a_rewrite_that_leaves_the_flagged_comment_is_rejected_and_the_next_try_is_told_why
    assert_equal 0, guided { first_then(NARRATED, QUICK) }
    assert_includes asked.last, "it still has 1 offense, and it had 1"
    assert_includes @out, "try 1: rejected"
  end

  def test_a_rewrite_that_fixes_a_rule_but_adds_a_flagged_comment_is_rejected
    assert_equal 0, guided(SLOW) { first_then(NARRATED, QUICK) }
    assert_includes asked.last, "WhatComment rose from 0 to 1"
    assert_equal QUICK, read("lib/a.rb")
  end

  def test_a_rule_and_a_guideline_broken_in_one_file_are_fixed_by_one_rewrite
    assert_equal 0, guided(BOTH) { fenced(QUICK) }
    assert_includes @out, "autocorrect: lib/a.rb MethodLength 1, WhatComment 1"
    assert_includes @out, "try 1: kept: 2 -> 0 offenses"
  end

  def test_a_method_a_guideline_flags_is_pointed_to_by_its_def
    jev { |state, _name| state["method"]&.include?("LONG") ? 0.9 : 0.1 }
    assert_equal 0, autocorrect(SLOW, sandi_yml: "guidelines:\n  - Demeter\n#{TESTED}") { fenced(QUICK) }
    assert_includes asked.first, 'line 1: Demeter: "def total": Does `method` reach through an object'
  end

  def test_only_files_with_something_found_in_them_are_sent
    guided_project { fenced(QUICK) }
    write("lib/b.rb", OTHER)
    sandi("--autocorrect")
    assert_equal 1, @model.requests.size
  end

  def test_with_no_guideline_turned_on_no_comment_is_judged
    assert_equal 0, autocorrect(NARRATED) { fenced(QUICK) }
    assert_empty @model.requests
    assert_includes @out, "autocorrect: no file counts against a rule"
  end

  def test_it_says_what_asking_jev_took
    guided { fenced(QUICK) }
    assert_includes @out, "asked Jev (typesafe/jev-1.14) through OpenRouter 1 question in "
    assert_includes @out, "120 input tokens, about $0.00001"
  end

  def test_it_says_nothing_of_jev_when_every_answer_it_needed_was_recorded
    guided_project { fenced(QUICK) }
    sandi
    sandi("--autocorrect")
    refute_includes @out, "asked Jev (typesafe"
  end

  def test_a_jev_that_refuses_to_judge_a_rewrite_stops_the_run_and_the_file_goes_back
    guided_project { fenced(CHANGED) }
    jev(statuses: [200, 401]) { |state, _name| state["comment"] == "add one" ? 0.9 : 0.1 }
    assert_equal 2, sandi("--autocorrect")
    assert_equal NARRATED, read("lib/a.rb")
    assert_includes @err, "answered 401"
  end

  def test_judging_a_rewrite_that_is_thrown_away_does_not_drop_the_answers_the_file_goes_back_to
    guided_project { fenced(CHANGED) }
    sandi("--autocorrect", "--update")
    assert_equal 2, @jev.requests.size
  end

  def test_update_after_autocorrect_drops_the_answers_for_comments_the_rewrite_removed
    guided_project { fenced(QUICK) }
    assert_equal 0, sandi("--autocorrect", "--update")
    assert_empty JSON.parse(File.read(File.join(@root, ".sandi-judgments.json")))
  end
end
