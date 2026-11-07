# frozen_string_literal: true

require "json"
require "socket"

# OpenRouter on localhost: a server that keeps every request, so a test can see what sandi asked and how it asked. It
# answers each with the next status the test gave, or with 200 and a reply, which is the next one the test gave or else
# what the subclass makes up.
class FakeServer
  Request = Data.define(:authorization, :body)

  attr_reader :requests

  def initialize(statuses: [], replies: [])
    @statuses, @replies, @requests = statuses.dup, replies.dup, []
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { loop { serve(@server.accept) } }
  end

  def url = "http://127.0.0.1:#{@server.addr[1]}#{self.class::PATH}"

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve(client)
    head = client.gets("\r\n\r\n")
    @requests << Request.new(authorization(head), read_body(client, head))
    reply(client, @statuses.shift || 200)
  ensure
    client.close
  end

  def authorization(head) = head[/^authorization: (.*)\r$/i, 1]

  def read_body(client, head) = JSON.parse(client.read(head[/^content-length: (\d+)/i, 1].to_i))

  def answer(body) = @replies.empty? ? made_up(body) : @replies.shift

  def reply(client, status)
    json = status == 200 ? answer(@requests.last.body) : {"error" => {"message" => "no", "code" => status}}
    body = JSON.generate(json)
    client.write("HTTP/1.1 #{status} Fake\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n" \
                 "Connection: close\r\n\r\n#{body}")
  end
end
