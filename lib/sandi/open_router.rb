# frozen_string_literal: true

require "json"
require "net/http"
require_relative "errors"

module Sandi
  # OpenRouter's web API, which sandi asks its models through: a JSON body posted to a URL with the key, asked again
  # after each pause when OpenRouter is rate limited or overloaded. The one place that knows it is a web API.
  class OpenRouter
    KEY = "OPENROUTER_API_KEY"
    # Rate limited or overloaded: worth asking again after each pause.
    BUSY = %w[429 500 502 503 504 529].freeze
    PAUSES = [1, 2].freeze

    # `who` is how an error names the model asked, as in "Jev (typesafe/jev-1.14) through OpenRouter".
    def initialize(url, who, read_timeout: 30, env: ENV)
      @uri, @who, @read_timeout, @key = URI(url), who, read_timeout, env[KEY]
    end

    def ready? = !@key.to_s.empty?
    def unready = "#{KEY} is not set"

    # The body of OpenRouter's answer to a post of `body`.
    def post(body, pauses = PAUSES)
      response = request(body)
      return response.body if response.is_a?(Net::HTTPSuccess)
      raise Error, refusal(response) unless BUSY.include?(response.code) && pauses.any?
      sleep(pauses.first)
      post(body, pauses.drop(1))
    end

    private

    def refusal(response) = "#{@who} answered #{response.code}: #{response.body}"

    def request(body)
      Net::HTTP.start(@uri.host, @uri.port, **connection) do |http|
        http.post(@uri.request_uri, body, "Authorization" => "Bearer #{@key}", "Content-Type" => "application/json")
      end
    rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, "#{@who} could not be reached: #{error.message}"
    end

    def connection = {use_ssl: @uri.scheme == "https", open_timeout: 10, read_timeout: @read_timeout}
  end
end
