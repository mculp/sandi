# frozen_string_literal: true

require_relative "fake_server"

# Jev on localhost, answering the way Jev does through OpenRouter: a noul for each question, by the question's name,
# from the block the test gives.
class FakeJev < FakeServer
  PATH = "/api/v1/systemone"

  def initialize(statuses: [], replies: [], &noul)
    @noul = noul
    super(statuses: statuses, replies: replies)
  end

  private

  # Every field Jev sends back: the answers by question name, the model that gave them and the tokens it read.
  def made_up(body)
    answers = body["questions"].keys.to_h { |name| [name, {"type" => "noul", "noul" => @noul.call(body["state"], name)}] }
    {"model" => "jev-1.14.0", "answers" => answers, "usage" => {"input_tokens" => 120, "output_tokens" => 12}}
  end
end
