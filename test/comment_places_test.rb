# frozen_string_literal: true

require_relative "test_helper"

# What a comment is read with, which is the code it is about. A guideline can only judge a comment against the code it
# is sent with, so which code that is decides what Jev can see. Here WhatComment is asked about every comment it reads,
# by a fake Jev on localhost that keeps what it was sent and says no.
module CommentPlacesHelpers
  # A tree of one file with WhatComment on and a Jev that says no.
  def tree_of(source)
    guidelines("WhatComment")
    jev { 0.1 }
    write("lib/a.rb", source)
    rubocop_reports("lib/a.rb" => [])
  end

  # The states Jev was sent for the tree, in any order, since requests are in flight at once.
  def asked_in(source)
    tree_of(source)
    sandi
    @jev.requests.map { |request| request.body["state"] }.sort_by { |state| JSON.generate(state) }
  end

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

  def test_a_comment_that_no_statement_holds_or_sits_above_is_not_asked_about
    assert_empty asked_in("require \"json\"\n\n# Nothing holds this.\n\nrequire \"yaml\"\n")
  end
end
