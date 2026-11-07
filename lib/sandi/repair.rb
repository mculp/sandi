# frozen_string_literal: true

require_relative "rewriter"

module Sandi
  # One file's autocorrection. The models are asked in turn, each for a few tries, and what checks out is kept and
  # built on: a rewrite that leaves offenses still counts, and the next try starts from it. When the tries are used up
  # the file is as the last rewrite that checked out made it, or as it was.
  class Repair
    TRIES = 3

    # `checks` measures a rewrite and judges it, and `out` is where each try is reported.
    def initialize(path, checks, out)
      @path, @checks, @out = path, checks, out
      @source, @counts, @problems = checks.read(path), checks.counts(path), checks.problems(path)
      @kept = false
    end

    def clean? = @counts.empty?
    def partly? = @kept && !clean?

    def call(rewriters)
      @out.puts("autocorrect: #{@path} #{@counts.sort.map { |name, count| "#{name} #{count}" }.join(", ")}")
      rewriters.each { |rewriter| ask(rewriter) }
      conclude
    ensure
      @checks.write(@path, @source)
    end

    private

    def conclude
      @out.puts(closing) unless clean?
      self
    end

    def ask(rewriter)
      @why = nil
      TRIES.times { |index| try(rewriter, index + 1) unless clean? }
    end

    def try(rewriter, number)
      @why = candidate(rewriter)
      @out.puts("  #{rewriter.model} try #{number}: #{outcome}")
      keep unless @why
    end

    # Why the model's rewrite is rejected, or nil when it is kept.
    def candidate(rewriter)
      @checks.write(@path, rewriter.rewrite(@path, @source, @problems, @why))
      @checks.verdict(@path, @counts, @source)
    rescue Rewriter::Unusable => unusable
      unusable.message
    end

    def outcome
      return "rejected: #{@why.lines.first.strip.chomp(":")}" if @why
      "kept: #{@counts.values.sum} -> #{@checks.counts(@path).values.sum} offenses"
    end

    def keep
      @source, @counts, @problems, @kept = @checks.read(@path), @checks.counts(@path), @checks.problems(@path), true
    end

    def closing
      @kept ? "  partly fixed: #{@path} has #{@counts.values.sum} left" : "  not fixed: #{@path} is as it was"
    end
  end
end
