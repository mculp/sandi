# frozen_string_literal: true

require "json"
require "prism"
require "yaml"
require_relative "errors"
require_relative "open_router"

module Sandi
  # A code model, through OpenRouter, asked to rewrite a Ruby file so that the offenses counted in it are gone. What it
  # answers is only a candidate: the caller keeps it if it checks out, so a bad rewrite costs a request and no more.
  class Rewriter
    # A reply with no Ruby in it. That is a bad try, not a failure to ask.
    Unusable = Class.new(StandardError)

    MODEL = "anthropic/claude-haiku-5.5"
    URL = "https://openrouter.ai/api/v1/chat/completions"
    INSTRUCTIONS = YAML.safe_load_file(File.expand_path("../../config/autocorrect.yml", __dir__)).fetch("instructions")
    # Room for a whole file, which is what the model gives back.
    MAX_TOKENS = 32_000
    CODE = /```(?:ruby)?\n(.*)```/m

    attr_reader :model

    # SANDI_AUTOCORRECT_URL sends the requests somewhere else, such as the fake model the tests run.
    def initialize(model = MODEL, env = ENV)
      @model = model
      @router = OpenRouter.new(env.fetch("SANDI_AUTOCORRECT_URL", URL), description, read_timeout: 300, env: env)
      @requests, @tokens_in, @tokens_out, @cost = 0, 0, 0, 0.0
    end

    def description = "#{@model} through OpenRouter"
    def ready? = @router.ready?
    def unready = @router.unready
    def asked? = @requests.positive?

    # What asking took, the way the rules' counters say what they counted.
    def report
      format("asked %s %d request%s: %d input tokens, %d output tokens, about $%.4f",
             description, @requests, ("s" unless @requests == 1), @tokens_in, @tokens_out, @cost)
    end

    # The file's source rewritten so that its offenses are gone, given what is wrong with it and, when an earlier try
    # was rejected, why.
    def rewrite(path, source, problems, why)
      reply = JSON.parse(@router.post(JSON.generate(request(path, source, problems, why))))
      raise TypeError, "the reply is not a JSON object" unless reply.is_a?(Hash)
      code(counted(reply))
    rescue JSON::ParserError, TypeError, Net::HTTPBadResponse => error
      raise Error, "#{description} answered in a way sandi can't read: #{error.message}"
    end

    private

    def request(path, source, problems, why)
      system = {"role" => "system", "content" => INSTRUCTIONS}
      user = {"role" => "user", "content" => brief(path, source, problems, why)}
      {"model" => @model, "max_tokens" => MAX_TOKENS, "usage" => {"include" => true}, "messages" => [system, user]}
    end

    def brief(path, source, problems, why)
      rejected = "Your last rewrite was rejected: #{why}\nTry again from the file as it is below.\n\n" if why
      listing = problems.map { |problem| "- #{problem}" }.join("\n")
      "#{rejected}File: #{path}\n\nOffenses:\n#{listing}\n\n```ruby\n#{source}```"
    end

    def code(reply)
      code = reply.dig("choices", 0, "message", "content").to_s[CODE, 1]
      raise Unusable, "the reply had no Ruby code block" unless code
      raise Unusable, "the reply was not valid Ruby" unless Prism.parse(code).success?
      code
    end

    def counted(reply) = reply.tap { tally(reply["usage"]) }

    def tally(usage)
      usage = {} unless usage.is_a?(Hash)
      @requests += 1
      @tokens_in += usage["prompt_tokens"].to_i
      @tokens_out += usage["completion_tokens"].to_i
      @cost += spent(usage)
    end

    # What OpenRouter charged, and with the project's own provider key, what the provider did: OpenRouter charges nothing
    # for that and says what the provider charged in the cost details.
    def spent(usage)
      return usage["cost"].to_f unless usage["is_byok"]
      usage["cost"].to_f + usage.dig("cost_details", "upstream_inference_cost").to_f
    end
  end
end
