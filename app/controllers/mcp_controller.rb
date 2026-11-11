# The MCP endpoint Claude connects to: POST /mcp with a JSON-RPC message.
# Authenticate with a bearer token: an OAuth access token (claude.ai connectors sign in
# through /oauth/authorize) or an API key (Claude Code and other clients that send headers).
class McpController < ActionController::Base
  include OwnerAuthentication

  skip_forgery_protection
  wrap_parameters false
  before_action :authenticate!

  def handle
    return head(:method_not_allowed, allow: "POST") unless request.post?

    payload = JSON.parse(request.raw_post)
    server = OrganizerModules.mcp_server
    if payload.is_a?(Array)
      responses = payload.filter_map { |m| server.handle(m) }
      responses.empty? ? head(:accepted) : render(json: responses)
    else
      result = server.handle(payload)
      result.nil? ? head(:accepted) : render(json: result)
    end
  rescue JSON::ParserError
    render json: { jsonrpc: "2.0", id: nil, error: { code: -32700, message: "Parse error" } }, status: :bad_request
  end

  private

  def authenticate!
    return if token_principal
    metadata = "#{Organizer.public_url}/.well-known/oauth-protected-resource/mcp"
    response.headers["WWW-Authenticate"] =
      %(Bearer error="invalid_token", error_description="Authentication required", resource_metadata="#{metadata}")
    render json: { error: "invalid_token", error_description: "Authentication required" }, status: :unauthorized
  end
end
