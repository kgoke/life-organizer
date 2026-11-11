ENV["RAILS_ENV"] ||= "test"
ENV["ADMIN_PASSWORD"] ||= "test-password-123"
ENV["PUBLIC_URL"] ||= "https://organizer.example.test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    # Rate limits count in the cache; start every test with a clean slate.
    setup { Rails.cache.clear }

    # Freeze "now" at a fixed, known moment: Wednesday 11 Nov 2026, 10:00 New York time.
    def freeze_now(&block)
      travel_to(Time.find_zone("America/New_York").local(2026, 11, 11, 10, 0), &block)
    end
  end
end

module ApiTestHelpers
  def api_key
    @api_key ||= ApiKey.generate!("test").last
  end

  def auth_headers(token = api_key)
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json", "Accept" => "application/json" }
  end

  def api(method, path, body = nil, token: api_key)
    send(method, path, params: body&.to_json, headers: auth_headers(token))
    response.parsed_body
  end

  def mcp(method, params = {}, id: 1, token: api_key)
    post "/mcp", params: { jsonrpc: "2.0", id: id, method: method, params: params }.to_json,
                 headers: auth_headers(token).merge("Accept" => "application/json, text/event-stream")
    response.parsed_body
  end

  def call_tool(name, args = {}, token: api_key)
    body = mcp("tools/call", { name: name, arguments: args }, token: token)
    result = body.fetch("result")
    [ result, JSON.parse(result["content"].first["text"]) ]
  rescue JSON::ParserError
    [ result, nil ]
  end

  def sign_in_owner
    post "/login", params: { password: ENV["ADMIN_PASSWORD"] }
  end
end

class ActionDispatch::IntegrationTest
  include ApiTestHelpers

  # PUBLIC_URL is https in tests, so the session cookie is marked secure, as in production.
  setup { https! }
end
