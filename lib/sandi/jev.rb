# frozen_string_literal: true

require "json"
require "net/http"
require_relative "errors"

module Sandi
  # Jev, TypeSafe's decision model, through OpenRouter. It reads a state and answers typed questions about it with
  # probabilities rather than text, which is what a count needs. The one place that knows it is a web API.
  class Jev
    # A version rather than the jev-latest alias, which moves to each release: recorded answers are one version's.
    MODEL = "typesafe/jev-1.14"
    URL = "https://openrouter.ai/api/v1/systemone"
    KEY = "OPENROUTER_API_KEY"
    # Dollars per input token. Output tokens are free.
    PRICE = 0.042 / 1_000_000
    # Rate limited or overloaded: worth asking again after each pause.
    BUSY = %w[429 500 502 503 504 529].freeze
    PAUSES = [1, 2].freeze

    # SANDI_JEV_URL sends the questions somewhere else, such as the fake Jev the tests run.
    def initialize(env = ENV)
      @key, @uri = env[KEY], URI(env.fetch("SANDI_JEV_URL", URL))
    end

    def model = MODEL
    def price = PRICE
    def description = "Jev (#{MODEL}) through OpenRouter"
    def ready? = !@key.to_s.empty?
    def unready = "#{KEY} is not set"

    # The noul for each question about the state, by the question's name, and the input tokens Jev read to answer.
    def nouls(state, questions)
      reply = JSON.parse(post(JSON.generate("model" => MODEL, "state" => state, "questions" => questions)))
      [questions.keys.to_h { |name| [name, noul(reply, name)] }, reply.dig("usage", "input_tokens").to_i]
    rescue JSON::ParserError, TypeError => error
      raise Error, "#{description} answered in a way sandi can't read: #{error.message}"
    end

    private

    def noul(reply, name) = reply.dig("answers", name, "noul") || raise(Error, "#{description} did not answer #{name}")

    def post(body, pauses = PAUSES)
      response = request(body)
      return response.body if response.is_a?(Net::HTTPSuccess)
      raise Error, refusal(response) unless BUSY.include?(response.code) && pauses.any?
      sleep(pauses.first)
      post(body, pauses.drop(1))
    end

    def refusal(response) = "#{description} answered #{response.code}: #{response.body}"

    def request(body)
      Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        http.post(@uri.path, body, "Authorization" => "Bearer #{@key}", "Content-Type" => "application/json")
      end
    rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, "#{description} could not be reached: #{error.message}"
    end
  end
end
