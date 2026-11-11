module Oauth
  class TokensController < ActionController::Base
    skip_forgery_protection
    wrap_parameters false

    def create
      response.headers["Cache-Control"] = "no-store"
      client = OauthFlow.authenticate_client!(params, request.authorization)
      body = case params[:grant_type]
      when "authorization_code" then OauthFlow.exchange_code!(client, params)
      when "refresh_token" then OauthFlow.refresh!(client, params)
      else raise OauthFlow::Error.new("unsupported_grant_type", "grant_type must be authorization_code or refresh_token")
      end
      render json: body
    rescue OauthFlow::Error => e
      status = e.code == "invalid_client" ? :unauthorized : :bad_request
      render json: { error: e.code, error_description: e.message }, status: status
    end

    def revoke
      OauthFlow.revoke!(params[:token]) if params[:token].present?
      head :ok
    end
  end
end
