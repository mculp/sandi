# frozen_string_literal: true

require_relative "baseline"
require_relative "comments"
require_relative "entry_points"
require_relative "errors"
require_relative "guidelines"
require_relative "jev"
require_relative "judge"
require_relative "judgments"
require_relative "offenses"
require_relative "ratchet"
require_relative "rubocop"
require_relative "settings"

module Sandi
  # The sandi command: reads the flags, builds what the counting needs, and answers with an exit status: 0 when no count rose,
  # 1 when one did, 2 when it could not count or was misused.
  class CLI
    USAGE = "usage: sandi [--update [--allow-increase]]"
    FLAGS = %w[--update --allow-increase].freeze
    BASELINE = ".sandi-baseline.json"
    JUDGMENTS = ".sandi-judgments.json"
    SETTINGS = ".sandi.yml"

    # The project measured is the one sandi runs in: its .rubocop.yml says what to look at, its .sandi.yml which
    # guidelines to judge, and its baseline what is allowed.

    def initialize(argv, root: Dir.pwd, out: $stdout, err: $stderr)
      @argv, @root, @out, @err = argv, root, out, err
    end

    def call
      return help if @argv.intersect?(%w[-h --help])
      return complain(USAGE) unless usable?
      update? ? ratchet.update(allow_increase: allow_increase?) : ratchet.check
    rescue Error => error
      complain(error.message)
    end

    private

    def usable? = (@argv - FLAGS).empty? && (update? || !allow_increase?)
    def update? = @argv.include?("--update")
    def allow_increase? = @argv.include?("--allow-increase")

    def ratchet
      offenses = Offenses.new(Rubocop.new(@root).report)
      counters = [offenses, EntryPoints.new(offenses.paths, root: @root), *guidelines(offenses.paths)]
      Ratchet.new(counters, baseline, @out)
    end

    # The guidelines .sandi.yml turns on, if any, asked of the comments in the files RuboCop inspected.
    def guidelines(paths)
      chosen = Settings.new(File.join(@root, SETTINGS)).guidelines
      return [] if chosen.empty?
      comments = paths.flat_map { |path| Comments.of(path, root: @root) }
      [Guidelines.new(chosen, comments, judge, baseline: baseline.tally(Guidelines::NAME))]
    end

    def judge = Judge.new(Jev.new, Judgments.new(File.join(@root, JUDGMENTS), prune: update?))
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
