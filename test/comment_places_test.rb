# frozen_string_literal: true

require_relative "test_helper"

# What a comment is read with, which is the code it is about. A guideline can only judge a comment against the code it
# is sent with, so which code that is decides what Jev can see. Here the guidelines named are asked about every comment
# they read, by a fake Jev on localhost that keeps what it was sent and says no.
module CommentPlacesHelpers
  # A tree of one file with the guidelines named on and a Jev that says no.
  def tree_of(source, names)
    guidelines(*names)
    jev { 0.1 }
    write("lib/a.rb", source)
    rubocop_reports("lib/a.rb" => [])
  end

  # What Jev was sent for the tree: each state with the names of the questions about it, in any order, since requests
  # are in flight at once.
  def requests_for(source, names)
    tree_of(source, names)
    sandi
    pairs = @jev.requests.map { |request| [request.body["state"], request.body["questions"].keys.sort] }
    pairs.sort_by { |pair| JSON.generate(pair) }
  end

  def asked_in(source, names = %w[WhatComment]) = requests_for(source, names).map(&:first)
  def state(comment, code) = {"comment" => comment, "code" => code}
end

class CommentPlacesTest < SandiCase
  include CommentPlacesHelpers

  def test_a_comment_above_a_constant_is_about_the_constant
    states = asked_in("class Tally\n  # How many there may be.\n  LIMIT = 4\nend\n")
    assert_equal [state("How many there may be.", "  LIMIT = 4\n")], states
  end

  def test_a_comment_above_a_require_is_about_the_require
    states = asked_in("# Loads what it needs.\nrequire \"json\"\n")
    assert_equal [state("Loads what it needs.", "require \"json\"\n")], states
  end

  def test_a_comment_above_a_constant_made_over_several_lines_is_about_all_of_it
    source = "# A count.\nCount = Data.define(:total) do\n  def to_s = total.to_s\nend\n"
    assert_equal [state("A count.", source.lines.drop(1).join)], asked_in(source)
  end

  def test_a_comment_above_a_heredoc_is_about_its_text_and_stops_where_it_ends
    source = "# What the tests print.\nTESTS = <<~TEXT\n  one\n  two\nTEXT\nOTHER = 1\n"
    assert_equal [state("What the tests print.", "TESTS = <<~TEXT\n  one\n  two\nTEXT\n")], asked_in(source)
  end

  def test_a_directive_between_a_comment_and_the_constant_under_it_does_not_separate_them
    states = asked_in("# Counts.\n# rubocop:disable Style/X\nLIMIT = 4\n")
    assert_equal [state("Counts.", "LIMIT = 4\n")], states
  end

  def test_a_comment_on_its_own_in_a_class_is_about_the_class
    source = "class Tally\n  def add = 1\n\n  # Floats on its own.\n\n  def total = 2\nend\n"
    assert_equal [state("Floats on its own.", source)], asked_in(source)
  end

  def test_a_comment_inside_a_constant_is_about_the_constant
    source = "FINDERS = {\n  # By kind.\n  \"a\" => 1\n}.freeze\n"
    assert_equal [state("By kind.", source)], asked_in(source)
  end

  def test_a_comment_inside_a_define_method_block_is_about_the_block
    source = "class Maker\n  define_method(:total) do |items|\n    # Add them up.\n    items.sum\n  end\nend\n"
    assert_equal [state("Add them up.", source.lines[1, 4].join)], asked_in(source)
  end

  def test_a_comment_that_no_statement_holds_or_sits_above_is_not_asked_about
    assert_empty asked_in("require \"json\"\n\n# Nothing holds this.\n\nrequire \"yaml\"\n")
  end
end

class TrailingCommentsTest < SandiCase
  include CommentPlacesHelpers

  def stale_in(source) = asked_in(source, %w[StaleComment])

  def test_a_comment_after_code_is_about_the_statement_it_follows
    states = stale_in("class Tally\n  LIMIT = 4 # most there may be\nend\n")
    assert_equal [state("most there may be", "  LIMIT = 4 # most there may be\n")], states
  end

  def test_a_comment_after_code_in_a_method_is_about_the_method
    source = "def total\n  @sum += 1 # by one\n  @sum\nend\n"
    assert_equal [state("by one", source)], stale_in(source)
  end

  def test_a_comment_after_a_def_is_about_the_def
    states = stale_in("class Cart\n  def total # the sum\n    1\n  end\n\n  def other = 2\nend\n")
    assert_equal [state("the sum", "  def total # the sum\n    1\n  end\n")], states
  end

  def test_a_comment_after_the_end_of_a_def_is_about_the_def
    states = stale_in("class Cart\n  def total\n    1\n  end # total\nend\n")
    assert_equal [state("total", "  def total\n    1\n  end # total\n")], states
  end

  def test_a_comment_after_the_start_of_a_block_is_about_all_of_it
    source = "Count = Data.define(:total) do # a count\n  def to_s = total.to_s\nend\n"
    assert_equal [state("a count", source)], stale_in(source)
  end

  def test_comments_after_code_on_lines_next_to_each_other_are_each_read_on_their_own
    states = stale_in("ONE = 1 # one\nTWO = 2 # two\n")
    assert_equal [state("one", "ONE = 1 # one\n"), state("two", "TWO = 2 # two\n")], states
  end

  def test_a_directive_after_code_is_not_a_comment_to_read
    assert_empty stale_in("LIMIT = 4 # rubocop:disable Style/X\n")
  end

  def test_only_stale_comment_is_asked_about_a_comment_after_code
    pairs = requests_for("LIMIT = 4 # most there may be\n", %w[WhatComment StaleComment])
    assert_equal [[state("most there may be", "LIMIT = 4 # most there may be\n"), %w[StaleComment]]], pairs
  end

  def test_a_project_without_stale_comment_reads_no_comment_after_code
    assert_empty asked_in("LIMIT = 4 # most there may be\n")
  end

  def test_the_baseline_says_stale_comment_is_asked_of_comments_after_code
    tree_of("LIMIT = 4\n", %w[WhatComment StaleComment])
    assert_equal 0, sandi("--update", "--allow-increase")
    counter = JSON.parse(baseline).dig("guidelines", "counter")
    assert_includes counter, "WhatComment, StaleComment asked of comments; StaleComment asked of trailing comments"
  end
end
