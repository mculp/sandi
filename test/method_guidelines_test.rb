# frozen_string_literal: true

require_relative "test_helper"

# Sandi's guidelines about methods: each def put to Jev, here a fake one on localhost, with its source as the state.
# They count in the same ratchet as the rules and the guidelines about comments, and each guideline is asked only about
# the kind of place it reads.
class MethodGuidelinesTest < SandiCase
  CART = <<~RUBY
    class Cart
      # The items in the cart.
      def initialize(items)
        @items = items
      end

      def total
        @items.map(&:price).sum
      end
    end
  RUBY
  INITIALIZE = "  def initialize(items)\n    @items = items\n  end\n"
  TOTAL = "  def total\n    @items.map(&:price).sum\n  end\n"
  FROM_THE_BOOKS = %w[AskForWhat Demeter InjectDependency TypeSwitch FlagParameter NullCheck].freeze

  # The cart, with the guidelines named turned on and a Jev that says yes (0.9) to every question about the methods
  # given and no (0.1) to the rest.
  def cart(*names, yes: [])
    guidelines(*names)
    jev { |state, _name| yes.include?(state["method"]) ? 0.9 : 0.1 }
    write("lib/cart.rb", CART)
    rubocop_reports("lib/cart.rb" => [])
  end

  # What sandi sent Jev to read, one state per request. Requests are in flight at once, so they arrive in any order.
  def states = @jev.requests.map { |request| request.body["state"] }.sort_by { |state| JSON.generate(state) }

  # Each request's state with the names of the questions asked about it.
  def asked
    pairs = @jev.requests.map { |request| [request.body["state"], request.body["questions"].keys.sort] }
    pairs.sort_by { |state, _names| JSON.generate(state) }
  end

  def test_a_method_guideline_is_asked_about_each_method_with_its_source_and_about_nothing_else
    cart("Demeter")
    sandi
    assert_equal [{"method" => INITIALIZE}, {"method" => TOTAL}], states
  end

  def test_every_def_is_asked_about_wherever_it_is_defined
    guidelines("Demeter")
    jev { 0.1 }
    write("lib/report.rb", <<~RUBY)
      Row = Data.define(:name) do
        def to_s = name
      end

      module Format
        class << self
          def plain(row) = row.to_s
        end

        def self.loud(row) = row.to_s.upcase
      end

      def report(rows)
        rows.map { |row| Format.loud(row) }
      end
    RUBY
    rubocop_reports("lib/report.rb" => [])
    sandi
    sources = ["    def plain(row) = row.to_s\n", "  def self.loud(row) = row.to_s.upcase\n", "  def to_s = name\n",
               "def report(rows)\n  rows.map { |row| Format.loud(row) }\nend\n"]
    assert_equal(sources.map { |source| {"method" => source} }, states)
  end

  def test_a_method_jev_says_yes_to_counts_against_its_file
    cart("Demeter", yes: [TOTAL])
    assert_equal 0, sandi("--update", "--allow-increase")
    assert_includes @out, "guidelines: 1 (Demeter 1) in 1 of 1 files"
    assert_equal({"lib/cart.rb" => {"Demeter" => 1}}, JSON.parse(baseline).dig("guidelines", "counts"))
  end

  def test_every_question_about_a_method_goes_in_one_request_and_each_yes_counts
    cart("AskForWhat", "Demeter", yes: [TOTAL])
    sandi("--update", "--allow-increase")
    both = %w[AskForWhat Demeter]
    assert_equal [[{"method" => INITIALIZE}, both], [{"method" => TOTAL}, both]], asked
    assert_includes @out, "guidelines: 2 (AskForWhat 1, Demeter 1) in 1 of 1 files"
  end

  def test_guidelines_about_comments_and_about_methods_are_each_asked_only_about_their_own_places
    cart("WhatComment", "Demeter")
    sandi
    comment = {"comment" => "The items in the cart.", "code" => INITIALIZE}
    expected = [[comment, %w[WhatComment]], [{"method" => INITIALIZE}, %w[Demeter]], [{"method" => TOTAL}, %w[Demeter]]]
    assert_equal expected, asked
  end

  def test_a_new_method_jev_says_yes_to_fails_and_is_pointed_to_at_its_def
    cart("Demeter", yes: [TOTAL])
    write("lib/cart.rb", CART.sub("\n#{TOTAL}", ""))
    assert_equal 0, sandi("--update", "--allow-increase")
    write("lib/cart.rb", CART)
    assert_equal 1, sandi
    assert_includes @out, "worse: lib/cart.rb Demeter 0 -> 1"
    assert_includes @out, "lib/cart.rb:7 Demeter 0.9"
  end

  def test_a_method_that_only_moves_is_not_asked_about_again
    cart("Demeter")
    sandi
    refute_empty @jev.requests
    @jev.requests.clear
    write("lib/cart.rb", "# frozen_string_literal: true\n\n#{CART}")
    sandi
    assert_empty @jev.requests
  end

  def test_a_method_whose_source_changes_is_asked_about_again
    cart("Demeter")
    sandi
    @jev.requests.clear
    write("lib/cart.rb", CART.sub("map(&:price).sum", "sum(&:price)"))
    sandi
    assert_equal [{"method" => "  def total\n    @items.sum(&:price)\n  end\n"}], states
  end

  def test_a_method_longer_than_a_class_is_sent_up_to_a_class_worth_of_lines
    guidelines("Demeter")
    jev { 0.1 }
    write("lib/long.rb", "def long\n#{"  step\n" * 120}end\n")
    rubocop_reports("lib/long.rb" => [])
    sandi
    assert_equal [{"method" => "def long\n#{"  step\n" * 99}"}], states
  end

  def test_the_baseline_says_which_guidelines_were_asked_of_comments_and_which_of_methods
    cart("WhatComment", "StaleComment", "Demeter")
    assert_equal 0, sandi("--update", "--allow-increase")
    counter =JSON.parse(baseline).dig("guidelines", "counter")
    assert_includes counter, "WhatComment, StaleComment asked of comments"
    assert_includes counter, "Demeter asked of methods"
  end

  def test_the_method_guidelines_from_the_books_can_each_be_turned_on
    cart(*FROM_THE_BOOKS)
    assert_equal 0, sandi
    assert_equal [[{"method" => INITIALIZE}, FROM_THE_BOOKS.sort], [{"method" => TOTAL}, FROM_THE_BOOKS.sort]], asked
  end

  def test_each_method_guideline_asks_a_noul_question_about_the_method_with_criteria_for_yes_and_no
    cart(*FROM_THE_BOOKS)
    sandi
    refute_empty @jev.requests
    @jev.requests.first.body["questions"].each do |name, question|
      assert_equal "noul", question["type"], name
      assert_includes question["instructions"], "`method`", name
      assert_equal %w[false true], question["criteria"].keys.sort, name
      refute question.key?("about"), "#{name}: what a guideline is about is sandi's to know, not Jev's"
    end
  end
end
