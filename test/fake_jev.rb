# frozen_string_literal: true

require "json"
require "socket"

# Jev on localhost, answering the way Jev does through OpenRouter: a noul for each question, by the question's name, from
# the block the test gives. It keeps every request, so a test can see what sandi asked and how it asked.
class FakeJev
  Request = Data.define(:authorization, :body)

  attr_reader :requests

  def initialize(statuses: [], &noul)
    @statuses, @noul, @requests = statuses.dup, noul, []
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { loop { serve(@server.accept) } }
  end

  def url = "http://127.0.0.1:#{@server.addr[1]}/api/v1/systemone"

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve(client)
    head = client.gets("\r\n\r\n")
    body = JSON.parse(client.read(head[/^content-length: (\d+)/i, 1].to_i))
    @requests << Request.new(head[/^authorization: (.*)\r$/i, 1], body)
    status = @statuses.shift || 200
    reply(client, status, status == 200 ? answer(@requests.last.body) : {"error" => {"message" => "no", "code" => status}})
  ensure
    client.close
  end

  # Every field Jev sends back: the answers by question name, the model that gave them and the tokens it read.
  def answer(body)
    answers = body["questions"].keys.to_h { |name| [name, {"type" => "noul", "noul" => @noul.call(body["state"], name)}] }
    {"model" => "jev-1.14.0", "answers" => answers, "usage" => {"input_tokens" => 120, "output_tokens" => 12}}
  end

  def reply(client, status, json)
    body = JSON.generate(json)
    client.write("HTTP/1.1 #{status} Fake\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n" \
                 "Connection: close\r\n\r\n#{body}")
  end
end
