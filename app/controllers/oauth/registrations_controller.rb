module Oauth
  # RFC 7591 dynamic client registration.
  class RegistrationsController < ActionController::Base
    skip_forgery_protection
    wrap_parameters false
    rate_limit to: 20, within: 1.hour, with: -> { render json: { error: "slow_down" }, status: :too_many_requests }

    def create
      return head(:not_found) unless Organizer.oauth_enabled?
      meta = JSON.parse(request.raw_post.presence || "{}")
      render json: OauthFlow.register!(meta), status: :created
    rescue JSON::ParserError
      render json: { error: "invalid_client_metadata", error_description: "body must be JSON" }, status: :bad_request
    rescue OauthFlow::Error => e
      render json: { error: e.code, error_description: e.message }, status: :bad_request
    end
  end
end
