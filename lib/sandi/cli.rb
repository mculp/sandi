# frozen_string_literal: true

require_relative "autocorrect"
require_relative "baseline"
require_relative "checks"
require_relative "entry_points"
require_relative "errors"
require_relative "guidelines"
require_relative "jev"
require_relative "judge"
require_relative "judgments"
require_relative "offenses"
require_relative "places"
require_relative "ratchet"
require_relative "rubocop"
require_relative "settings"

module Sandi
  # The sandi command: reads the flags, builds what the counting needs, and answers with an exit status: 0 when no count rose,
  # 1 when one did, 2 when it could not count or was misused.
  class CLI
    USAGE = "usage: sandi [--autocorrect] [--update [--allow-increase]]"
    FLAGS = %w[--autocorrect --update --allow-increase].freeze
    BASELINE = ".sandi-baseline.json"
    JUDGMENTS = ".sandi-judgments.json"
    SETTINGS = ".sandi.yml"
    NEEDS_TESTS = "autocorrect needs a test command, so that a rewrite is kept only if the tests still pass. Add one to " \
                  ".sandi.yml, as in autocorrect: {test: bundle exec rake test}"

    # The project measured is the one sandi runs in: its .rubocop.yml says what to look at, its .sandi.yml which
    # guidelines to judge and how to autocorrect, and its baseline what is allowed.

    def initialize(argv, root: Dir.pwd, out: $stdout, err: $stderr)
      @argv, @root, @out, @err = argv, root, out, err
    end

    def call
      return help if @argv.intersect?(%w[-h --help])
      return complain(USAGE) unless usable?
      run
    rescue Error => error
      complain(error.message)
    end

    private

    def run
      autocorrect if autocorrect?
      update? ? ratchet.update(allow_increase: allow_increase?) : ratchet.check
    end

    def usable? = (@argv - FLAGS).empty? && (update? || !allow_increase?)
    def autocorrect? = @argv.include?("--autocorrect")
    def update? = @argv.include?("--update")
    def allow_increase? = @argv.include?("--allow-increase")

    # The counters of the rules and of the guidelines .sandi.yml turns on, which read the files as they are now. `judge`
    # answers the guidelines.
    def counters(judge)
      offenses = Offenses.new(Rubocop.new(@root).report)
      [offenses, EntryPoints.new(offenses.paths, root: @root), *guidelines(offenses.paths, judge)]
    end

    def ratchet = Ratchet.new(counters(judge(prune: update?)), baseline, @out)

    # The files that count against a rule or a guideline, rewritten by the models .sandi.yml names where a rewrite
    # checks out. Jev judges the rewrites with a record that is never pruned: a rewrite thrown away puts its file back,
    # and the answers that file goes back to must still be there.
    def autocorrect
      how = settings.autocorrect
      raise Error, NEEDS_TESTS unless how.test
      judging = judge(prune: false)
      Autocorrect.new(rewriters(how), Checks.new(@root, -> { counters(judging) }, how.test), @out).call
      @out.puts(judging.spent) if judging.asked?
    end

    def rewriters(how)
      all = how.models.map { |model| Rewriter.new(model, guidelines: settings.guidelines) }
      raise Error, "autocorrect asks #{all.first.description}, and #{all.first.unready}" unless all.first.ready?
      all
    end

    def settings = @settings ||= Settings.new(File.join(@root, SETTINGS))

    # The guidelines .sandi.yml turns on, if any, asked of the comments or methods in the files RuboCop inspected.
    def guidelines(paths, judge)
      chosen = settings.guidelines
      return [] if chosen.empty?
      [Guidelines.new(chosen, Places.new(paths, root: @root), judge, baseline: baseline.tally(Guidelines::NAME))]
    end

    # Jev's answers are kept in a record that drops the ones the tree no longer uses only when `prune` says to.
    def judge(prune:) = Judge.new(Jev.new, Judgments.new(File.join(@root, JUDGMENTS), prune: prune))
    def baseline = @baseline ||= Baseline.new(File.join(@root, BASELINE))

    def help
      @out.puts(USAGE)
      0
    end

    def complain(message)
      @err.puts(message)
      2
    end
  end
end
