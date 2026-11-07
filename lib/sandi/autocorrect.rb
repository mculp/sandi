# frozen_string_literal: true

require_relative "repair"

module Sandi
  # Asks code models to rewrite each file that counts against a rule, and keeps a rewrite only if Checks lets it
  # through. Each file is a Repair; this goes through them and says how many came out clean and what asking cost.
  class Autocorrect
    def initialize(rewriters, checks, out)
      @rewriters, @checks, @out = rewriters, checks, out
      @out.sync = true
    end

    def call
      paths = @checks.offending
      return @out.puts("autocorrect: no file counts against a rule") if paths.empty?
      repairs = paths.map { |path| Repair.new(path, @checks, @out).call(@rewriters) }
      @out.puts(summary(repairs), *@rewriters.select(&:asked?).map(&:report))
    end

    private

    def summary(repairs)
      partly = repairs.count(&:partly?)
      fixed = "autocorrect: fixed #{repairs.count(&:clean?)} of #{repairs.size} files"
      partly.positive? ? "#{fixed}, partly fixed #{partly}" : fixed
    end
  end
end
