require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  test "pages need sign-in and the password works" do
    get "/"
    assert_redirected_to "/login"
    post "/login", params: { password: "nope" }
    assert_redirected_to "/login"
    assert_equal "Wrong password.", flash[:alert]
    sign_in_owner
    assert_redirected_to "/"
    %w[/ /tasks /tasks?filter=done /calendar /events/new /settings].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "the API refuses missing, wrong and revoked keys" do
    get "/api/v1/tasks"
    assert_response :unauthorized
    get "/api/v1/tasks", headers: auth_headers("lo_wrong")
    assert_response :unauthorized
    record, raw = ApiKey.generate!("phone")
    get "/api/v1/tasks", headers: auth_headers(raw)
    assert_response :success
    assert record.reload.last_used_at
    record.revoke!
    get "/api/v1/tasks", headers: auth_headers(raw)
    assert_response :unauthorized
  end

  test "keys are stored only as digests" do
    record, raw = ApiKey.generate!("x")
    refute_includes record.attributes.values.map(&:to_s), raw
  end

  test "a signed-in browser can use the API with its CSRF token but not without" do
    sign_in_owner
    ActionController::Base.allow_forgery_protection = true
    get "/calendar"
    token = css_select('meta[name="csrf-token"]').first["content"]
    post "/api/v1/tasks", params: { title: "From the calendar" }.to_json,
                          headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
    assert_response :created
    post "/api/v1/tasks", params: { title: "No token" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
