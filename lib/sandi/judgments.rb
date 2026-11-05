# frozen_string_literal: true

require "json"
require_relative "errors"

module Sandi
  # The committed file of Jev's answers, each under the key of the judgment it answered. A model's answer to a
  # borderline question can change when it is asked again, and a ratchet must count the same tree the same way, so an
  # answer once given is the answer. Updating the baseline drops the answers the tree no longer uses.
  class Judgments
    def initialize(path, prune:)
      @path, @prune = path, prune
    end

    def noul(key) = recorded[key]
    def record(key, noul) = (recorded[key] = noul.round(3))

    # Writes what is recorded if that changed, keeping only the given keys when pruning.
    def save(keys)
      kept = (@prune ? recorded.slice(*keys) : recorded).sort.to_h
      File.write(@path, "#{JSON.pretty_generate(kept)}\n") unless kept == read
    end

    private

    def recorded = @recorded ||= read

    def read
      File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    rescue JSON::ParserError => error
      raise Error, "#{@path} is not valid JSON: #{error.message}"
    end
  end
end
