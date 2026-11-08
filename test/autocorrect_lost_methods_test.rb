# frozen_string_literal: true

require_relative "autocorrect_helper"
require_relative "test_helper"

# Tests that pass prove little if a rewrite deleted the failing ones, so autocorrect rejects a rewrite that no longer
# defines a method the file defined, whether the method was made with def or with a define_method block.
class AutocorrectLostMethodsTest < SandiCase
  include AutocorrectHelper

  def test_a_rewrite_that_loses_a_method_is_rejected_even_though_the_tests_pass
    assert_equal 0, autocorrect { first_then("def other = 1\n", QUICK) }
    assert_includes asked.last, "it no longer defines total"
    assert_equal QUICK, read("lib/a.rb")
  end

  def test_a_rewrite_that_loses_a_define_method_block_is_rejected_even_though_the_tests_pass
    assert_equal 0, autocorrect(SLOW_BLOCK) { first_then("define_method(:other) { 1 }\n", QUICK_BLOCK) }
    assert_includes asked.last, "it no longer defines total"
    assert_equal QUICK_BLOCK, read("lib/a.rb")
  end

  def test_a_rewrite_that_loses_a_define_method_block_with_a_computed_name_is_rejected
    assert_equal 0, autocorrect(COMPUTED) { first_then("def other = 1\n", "define_method(name) { 1 }\n") }
    assert_includes asked.last, "it no longer defines define_method(name)"
  end

  def test_a_def_rewritten_as_a_define_method_block_of_the_same_name_loses_nothing
    assert_equal 0, autocorrect { fenced("define_method(\"total\") { 1 }\n") }
    assert_equal 1, @model.requests.size
  end
end
