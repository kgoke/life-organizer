require "test_helper"

class OauthTest < ActionDispatch::IntegrationTest
  REDIRECT = "https://claude.ai/api/mcp/auth_callback".freeze

  setup do
    @verifier = SecureRandom.urlsafe_base64(48)
    @challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false)
  end

  def register
    post "/oauth/register", params: { client_name: "Claude", redirect_uris: [ REDIRECT ], token_endpoint_auth_method: "none" }.to_json,
                            headers: { "Content-Type" => "application/json" }
    assert_response :created
    response.parsed_body["client_id"]
  end

  def auth_params(client_id)
    { response_type: "code", client_id: client_id, redirect_uri: REDIRECT, code_challenge: @challenge,
      code_challenge_method: "S256", state: "abc", scope: "organizer", resource: "https://organizer.example.test/mcp" }
  end

  def authorize(client_id, password: ENV["ADMIN_PASSWORD"])
    get "/oauth/authorize", params: auth_params(client_id)
    assert_response :success
    post "/oauth/authorize", params: auth_params(client_id).merge(decision: "allow", password: password)
  end

  def code_from_redirect
    assert_response :redirect
    uri = URI(response.location)
    assert_equal REDIRECT, "#{uri.scheme}://#{uri.host}#{uri.path}"
    q = Rack::Utils.parse_query(uri.query)
    assert_equal "abc", q["state"]
    q["code"]
  end

  test "metadata documents" do
    get "/.well-known/oauth-protected-resource/mcp"
    assert_equal "https://organizer.example.test/mcp", response.parsed_body["resource"]
    get "/.well-known/oauth-authorization-server"
    body = response.parsed_body
    assert_equal "https://organizer.example.test/oauth/token", body["token_endpoint"]
    assert_includes body["code_challenge_methods_supported"], "S256"
  end

  test "full flow: register, consent, token, use, refresh, revoke" do
    client_id = register
    authorize(client_id, password: "wrong")
    assert_response :unauthorized

    authorize(client_id)
    code = code_from_redirect

    post "/oauth/token", params: { grant_type: "authorization_code", code: code, redirect_uri: REDIRECT, client_id: client_id, code_verifier: "x" * 50 }
    assert_response :bad_request

    authorize(client_id)
    code = code_from_redirect
    post "/oauth/token", params: { grant_type: "authorization_code", code: code, redirect_uri: REDIRECT, client_id: client_id, code_verifier: @verifier }
    assert_response :success
    tokens = response.parsed_body
    assert tokens["access_token"].start_with?("loa_")

    post "/oauth/token", params: { grant_type: "authorization_code", code: code, redirect_uri: REDIRECT, client_id: client_id, code_verifier: @verifier }
    assert_response :bad_request, "a code works only once"

    assert_equal({}, mcp("ping", token: tokens["access_token"])["result"])

    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], client_id: client_id }
    assert_response :success
    fresh = response.parsed_body
    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], client_id: client_id }
    assert_response :bad_request, "refresh tokens rotate"
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json, headers: auth_headers(tokens["access_token"])
    assert_response :unauthorized

    post "/oauth/revoke", params: { token: fresh["access_token"], client_id: client_id }
    assert_response :success
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json, headers: auth_headers(fresh["access_token"])
    assert_response :unauthorized
  end

  test "deny sends the user back with access_denied" do
    client_id = register
    post "/oauth/authorize", params: auth_params(client_id).merge(decision: "deny")
    assert_includes response.location, "error=access_denied"
  end

  test "an unregistered redirect address is refused, not redirected to" do
    client_id = register
    get "/oauth/authorize", params: auth_params(client_id).merge(redirect_uri: "https://evil.example/cb")
    assert_response :bad_request
  end

  test "disconnecting an app in settings revokes its tokens" do
    client_id = register
    authorize(client_id)
    code = code_from_redirect
    post "/oauth/token", params: { grant_type: "authorization_code", code: code, redirect_uri: REDIRECT, client_id: client_id, code_verifier: @verifier }
    access = response.parsed_body["access_token"]
    sign_in_owner
    delete "/settings/connected_apps/#{OauthClient.find_by(client_id: client_id).id}"
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json, headers: auth_headers(access)
    assert_response :unauthorized
  end
end
