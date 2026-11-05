# frozen_string_literal: true

require_relative "judgment"
require_relative "tally"

module Sandi
  # Sandi's guidelines, the judgment calls beside her rules: for each file, the places that a guideline the project
  # turned on gets a yes for. Each guideline is asked only about the kind of place it reads, comments or methods. A yes
  # is a noul of 0.7 or more, where TypeSafe suggests starting to act on one. When an answer is missing and Jev can't
  # be asked, nothing is judged and the baseline's counts stand.
  class Guidelines
    NAME = "guidelines"
    YES = 0.7

    def initialize(guidelines, places, judge, baseline:)
      @guidelines, @places, @judge, @baseline = guidelines, places, judge, baseline
    end

    def name = NAME
    def description = "#{asked_of.join("; ")} by #{@judge.description}, a yes at #{YES}"
    def tally = @tally ||= judged? ? Tally.new(yeses.keys.map(&:counts_against).tally) : @baseline
    def summary = judged? ? [counts, *pointers, @judge.report(judgments)] : unjudged

    private

    def judged? = @judge.able?(judgments)
    def judgments = @judgments ||= @guidelines.flat_map { |guideline| judgments_of(guideline) }
    def judgments_of(guideline) = @places.of(guideline.about).map { |place| Judgment.new(place, guideline) }
    def yeses = @yeses ||= @judge.nouls(judgments).select { |_judgment, noul| noul >= YES }

    # Which guidelines were asked of which kind of place, as in "WhatComment, StaleComment asked of comments".
    def asked_of = @guidelines.group_by(&:about).map { |about, guidelines| "#{names(guidelines)} asked of #{about}s" }
    def names(guidelines) = guidelines.map(&:name).join(", ")

    def counts = "#{NAME}: #{tally.total} (#{kinds}) in #{tally.file_count} of #{judgments.map(&:file).uniq.size} files"
    def kinds = tally.by_name.map { |guideline, count| "#{guideline} #{count}" }.join(", ")
    def unjudged = "#{NAME}: not judged, so the baseline's counts stand: #{@judge.excuse(judgments)}"

    # Where the yeses are in a file whose count rose: no other tool can show them.
    def pointers
      risen = tally.changes_from(@baseline).select(&:worse?).map { |change| [change.file, change.name] }
      found = yeses.select { |judgment, _noul| risen.include?(judgment.counts_against) }
      found.map { |judgment, noul| "  #{judgment.file}:#{judgment.line} #{judgment.name} #{noul}" }.sort
    end
  end
end
