# frozen_string_literal: true

require "minitest/mock"
require_relative "test_helper"

# Sandi's guidelines about methods: each def put to Jev, here a fake one on localhost, with its source as the state.
# They count in the same ratchet as the rules and the guidelines about comments, and each guideline is asked only about
# the kind of place it reads.
module MethodGuidelinesFixtures
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
  # What Jev reads about each of the cart's methods: its own source, as though it began its line.
  INITIALIZE = "def initialize(items)\n  @items = items\nend"
  TOTAL = "def total\n  @items.map(&:price).sum\nend"
  CART_WITHOUT_TOTAL = CART.sub("\n  def total\n    @items.map(&:price).sum\n  end\n", "")
  MOVED_CART = "# frozen_string_literal: true\n\n#{CART}"
  FROM_THE_BOOKS = %w[AskForWhat Demeter InjectDependency TypeSwitch FlagParameter NullCheck].freeze
  REPORT = <<~RUBY
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
  SHOP = <<~RUBY
    Item = Struct.new(:price) { def to_s = price.to_s }
    class Shelf; def size = 3; def empty? = size.zero?; end
    class Basket
      private def subtotal
        @items.sum(&:price)
      end
    end
  RUBY
end

module MethodGuidelinesHelpers
  include MethodGuidelinesFixtures

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

  def demeter_says(score)
    guidelines("Demeter")
    jev { score }
  end

  def sandi_reads(path, content)
    demeter_says(0.1)
    write(path, content)
    rubocop_reports(path => [])
    sandi
  end

  def record_baseline(files)
    files.each { |path, content| write(path, content) }
    rubocop_reports(**files.transform_values { [] })
    sandi("--update", "--allow-increase")
  end

  def ask_then_forget
    sandi
    @jev.requests.clear
  end

  def ask_and_forget
    sandi
    refute_empty @jev.requests
    @jev.requests.clear
  end

  def method_states(sources) = sources.map { |source| {"method" => source} }

  def assert_noul(name, question)
    assert_equal "noul", question["type"], name
    assert_includes question["instructions"], "`method`", name
    assert_equal %w[false true], question["criteria"].keys.sort, name
    refute question.key?("about"), "#{name}: what a guideline is about is sandi's to know, not Jev's"
  end

  def assert_total_is_worse
    assert_equal 1, sandi
    assert_includes @out, "worse: lib/cart.rb Demeter 0 -> 1"
    assert_includes @out, "lib/cart.rb:7 Demeter 0.9"
  end
end

class MethodGuidelinesTest < SandiCase
  include MethodGuidelinesHelpers

  def test_a_file_is_parsed_once_however_many_kinds_of_place_are_asked_about
    cart("WhatComment", "Demeter")
    parses = 0
    real = Prism.method(:parse_file)
    Prism.stub(:parse_file, ->(path) { parses += 1; real.call(path) }) { sandi }
    assert_equal 1, parses
  end

  def test_a_method_guideline_is_asked_about_each_method_with_its_source_and_about_nothing_else
    cart("Demeter")
    sandi
    assert_equal [{"method" => INITIALIZE}, {"method" => TOTAL}], states
  end

  def test_every_def_is_asked_about_wherever_it_is_defined
    sandi_reads("lib/report.rb", REPORT)
    sources = ["def plain(row) = row.to_s", "def report(rows)\n  rows.map { |row| Format.loud(row) }\nend",
               "def self.loud(row) = row.to_s.upcase", "def to_s = name"]
    assert_equal(method_states(sources), states)
  end

  def test_a_def_is_sent_as_its_own_source_without_the_code_it_shares_a_line_with
    sandi_reads("lib/shop.rb", SHOP)
    sources = ["def empty? = size.zero?", "def size = 3", "def subtotal\n  @items.sum(&:price)\nend",
               "def to_s = price.to_s"]
    assert_equal(method_states(sources), states)
  end

  def test_each_def_counts_even_beside_one_on_its_line_that_reads_the_same
    demeter_says(0.9)
    twins = "class Order; def name = @order.owner.name; end; class Gift; def name = @order.owner.name; end\n"
    assert_equal 0, record_baseline("lib/names.rb" => twins)
    assert_includes @out, "guidelines: 2 (Demeter 2) in 1 of 1 files"
  end

  def test_methods_that_read_the_same_are_asked_about_once_and_each_counts
    demeter_says(0.9)
    assert_equal 0, record_baseline("lib/order.rb" => "class Order\n  def owner_name = @order.owner.name\nend\n",
                                    "lib/gift.rb" => "def owner_name = @order.owner.name\n")
    assert_equal [{"method" => "def owner_name = @order.owner.name"}], states
    assert_includes @out, "guidelines: 2 (Demeter 2) in 2 of 2 files"
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
    comment = {"comment" => "The items in the cart.", "code" => "  def initialize(items)\n    @items = items\n  end\n"}
    expected = [[comment, %w[WhatComment]], [{"method" => INITIALIZE}, %w[Demeter]], [{"method" => TOTAL}, %w[Demeter]]]
    assert_equal expected, asked
  end
end

class MethodGuidelinesRatchetTest < SandiCase
  include MethodGuidelinesHelpers

  def test_a_new_method_jev_says_yes_to_fails_and_is_pointed_to_at_its_def
    cart("Demeter", yes: [TOTAL])
    write("lib/cart.rb", CART_WITHOUT_TOTAL)
    assert_equal 0, sandi("--update", "--allow-increase")
    write("lib/cart.rb", CART)
    assert_total_is_worse
  end

  def test_a_method_that_only_moves_is_not_asked_about_again
    cart("Demeter")
    ask_and_forget
    write("lib/cart.rb", MOVED_CART)
    sandi
    assert_empty @jev.requests
  end

  def test_a_method_whose_source_changes_is_asked_about_again
    cart("Demeter")
    ask_then_forget
    write("lib/cart.rb", CART.sub("map(&:price).sum", "sum(&:price)"))
    sandi
    assert_equal [{"method" => "def total\n  @items.sum(&:price)\nend"}], states
  end

  def test_a_method_longer_than_a_class_is_sent_up_to_a_class_worth_of_lines
    sandi_reads("lib/long.rb", "def long\n#{"  step\n" * 120}end\n")
    assert_equal [{"method" => "def long\n#{"  step\n" * 99}"}], states
  end

  def test_the_baseline_says_which_guidelines_were_asked_of_comments_and_which_of_methods
    cart("WhatComment", "StaleComment", "Demeter")
    assert_equal 0, sandi("--update", "--allow-increase")
    counter = JSON.parse(baseline).dig("guidelines", "counter")
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
    @jev.requests.first.body["questions"].each { |name, question| assert_noul(name, question) }
  end
end
