# frozen_string_literal: true

require_relative "fake_server"

# A code model on localhost, answering the way a chat model does through OpenRouter: the text the block gives for the
# messages it was sent, with the tokens it read and wrote and what that cost.
class FakeModel < FakeServer
  PATH = "/api/v1/chat/completions"

  def initialize(statuses: [], replies: [], &content)
    @content = content
    super(statuses: statuses, replies: replies)
  end

  private

  def made_up(body)
    {"choices" => [{"message" => {"role" => "assistant", "content" => @content.call(body)}}],
     "usage" => {"prompt_tokens" => 1000, "completion_tokens" => 500, "cost" => 0.01}}
  end
end
