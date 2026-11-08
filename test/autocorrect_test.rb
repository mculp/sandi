# frozen_string_literal: true

require_relative "autocorrect_helper"
require_relative "test_helper"

# `sandi --autocorrect`: a code model, here a fake one on localhost, asked to rewrite the files that count against the
# rules. A rewrite is kept only when it takes offenses away, adds none of another kind, and leaves the project's tests
# passing. Otherwise the file goes back as it was.
class AutocorrectTest < SandiCase
  include AutocorrectHelper

  def test_a_file_over_the_limit_is_rewritten_and_kept_when_that_clears_it
    assert_equal 0, autocorrect { fenced(QUICK) }
    assert_equal QUICK, read("lib/a.rb")
    assert_includes @out, "autocorrect: fixed 1 of 1 files"
  end

  def test_the_model_is_sent_the_file_and_what_is_wrong_with_it
    autocorrect { fenced(QUICK) }
    assert_includes asked.first, "lib/a.rb"
    assert_includes asked.first, SLOW
    assert_includes asked.first, "line 2: MethodLength: Method has too many lines. [9/5]"
  end

  def test_a_rewrite_that_leaves_the_offense_is_rejected_and_the_next_try_is_told_why
    assert_equal 0, autocorrect { first_then(SLOW, QUICK) }
    assert_includes asked.last, "it still has 1 offense, and it had 1"
    assert_includes @out, "try 1: rejected"
    assert_includes @out, "try 2: kept"
  end

  def test_a_rewrite_that_clears_only_some_offenses_is_kept_and_the_next_try_goes_on_from_it
    assert_equal 0, autocorrect(TWICE) { first_then(SLOW, QUICK) }
    assert_includes asked.last, SLOW
    assert_includes @out, "try 1: kept: 2 -> 1 offenses"
    assert_equal QUICK, read("lib/a.rb")
  end

  def test_what_improved_stays_when_offenses_are_left_after_the_tries
    assert_equal 1, autocorrect(TWICE) { fenced(SLOW) }
    assert_equal SLOW, read("lib/a.rb")
    assert_includes @out, "partly fixed: lib/a.rb has 1 left"
    assert_includes @out, "autocorrect: fixed 0 of 1 files, partly fixed 1"
  end

  def test_a_model_that_fixes_one_offense_at_a_time_gets_three_tries_and_the_next_model_goes_on
    assert_equal 0, autocorrect(FIVE, sandi_yml: "#{TESTED}  model: [a/one, b/two]\n") { |body| one_less(body) }
    assert_equal %w[a/one a/one a/one b/two b/two], @model.requests.map { |request| request.body["model"] }
  end

  def test_a_rewrite_that_was_rejected_is_not_left_in_the_file
    assert_equal 1, autocorrect { fenced(BROKEN) }
    assert_equal SLOW, read("lib/a.rb")
  end

  def test_after_a_partial_fix_a_rejected_rewrite_leaves_the_fix_in_the_file
    assert_equal 1, autocorrect(TWICE) { first_then(SLOW, BROKEN) }
    assert_equal SLOW, read("lib/a.rb")
  end

  def test_after_three_failed_tries_the_file_is_as_it_was_and_the_run_fails
    assert_equal 1, autocorrect { fenced(SLOW) }
    assert_equal SLOW, read("lib/a.rb")
    assert_equal 3, @model.requests.size
    assert_includes @out, "not fixed: lib/a.rb is as it was"
  end

  def test_a_rewrite_that_fails_the_project_tests_is_rejected
    assert_equal 0, autocorrect { first_then(BROKEN, QUICK) }
    assert_includes asked.last, "the tests failed:"
    assert_includes asked.last, "BROKEN found in lib/a.rb"
    assert_includes asked.last, SLOW
    assert_includes @out, "try 1: rejected: the tests failed\n"
  end

  def test_a_rewrite_that_adds_an_offense_of_another_kind_is_rejected
    assert_equal 0, autocorrect { first_then("def total = 1 # BIG\n", QUICK) }
    assert_includes asked.last, "ClassLength rose from 0 to 1"
  end

  def test_a_reply_that_is_not_ruby_is_rejected
    assert_equal 0, autocorrect { first_then("def (", QUICK) }
    assert_includes asked.last, "the reply was not valid Ruby"
  end

  def test_a_reply_without_a_code_block_is_rejected
    assert_equal 0, autocorrect { @model.requests.size == 1 ? "I would split the method." : fenced(QUICK) }
    assert_includes asked.last, "the reply had no Ruby code block"
  end

  def test_only_files_with_offenses_are_sent
    project
    write("lib/b.rb", QUICK)
    model { fenced(QUICK) }
    sandi("--autocorrect")
    assert_equal 1, @model.requests.size
  end

  def test_an_entry_point_over_the_limit_is_rewritten_too
    project(QUICK)
    write("exe/tool", "#!/usr/bin/env ruby\nOne.call\nTwo.call\n")
    model { fenced("#!/usr/bin/env ruby\nOne.call\n") }
    assert_equal 0, sandi("--autocorrect")
    assert_equal "#!/usr/bin/env ruby\nOne.call\n", read("exe/tool")
  end

  def test_when_the_first_model_cannot_fix_a_file_the_next_is_asked
    autocorrect(sandi_yml: "#{TESTED}  model: [a/one, b/two]\n") { |body| fenced(body["model"] == "a/one" ? SLOW : QUICK) }
    assert_equal %w[a/one a/one a/one b/two], @model.requests.map { |request| request.body["model"] }
    assert_equal QUICK, read("lib/a.rb")
  end

  def test_update_after_autocorrect_writes_the_baseline_with_what_is_left
    project
    model { fenced(QUICK) }
    assert_equal 0, sandi("--autocorrect", "--update")
    assert_equal({}, JSON.parse(baseline).dig("offenses", "counts"))
  end
end
