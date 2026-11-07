# frozen_string_literal: true

require "json"
require_relative "errors"
require_relative "open_router"

module Sandi
  # Jev, TypeSafe's decision model, through OpenRouter. It reads a state and answers typed questions about it with
  # probabilities rather than text, which is what a count needs.
  class Jev
    # A version rather than the jev-latest alias, which moves to each release: recorded answers are one version's.
    MODEL = "typesafe/jev-1.14"
    URL = "https://openrouter.ai/api/v1/systemone"
    # Dollars per input token. Output tokens are free.
    PRICE = 0.042 / 1_000_000

    # SANDI_JEV_URL sends the questions somewhere else, such as the fake Jev the tests run.
    def initialize(env = ENV)
      @router = OpenRouter.new(env.fetch("SANDI_JEV_URL", URL), description, env: env)
    end

    def model = MODEL
    def price = PRICE
    def description = "Jev (#{MODEL}) through OpenRouter"
    def ready? = @router.ready?
    def unready = @router.unready

    # The noul for each question about the state, by the question's name, and the input tokens Jev read to answer.
    def nouls(state, questions)
      reply = JSON.parse(@router.post(JSON.generate("model" => MODEL, "state" => state, "questions" => questions)))
      raise TypeError, "the reply is not a JSON object" unless reply.is_a?(Hash)
      [questions.keys.to_h { |name| [name, noul(reply, name)] }, reply.dig("usage", "input_tokens").to_i]
    rescue JSON::ParserError, TypeError, Net::HTTPBadResponse => error
      raise Error, "#{description} answered in a way sandi can't read: #{error.message}"
    end

    private

    # A noul is a number, so an answer that isn't one is no answer.
    def noul(reply, name)
      noul = reply.dig("answers", name, "noul")
      noul.is_a?(Numeric) ? noul : raise(Error, "#{description} did not answer #{name}")
    end
  end
end
