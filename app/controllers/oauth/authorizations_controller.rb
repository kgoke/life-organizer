module Oauth
  # The consent page: the owner confirms (with the app password, if not signed in) that an
  # app such as Claude may use the organizer.
  class AuthorizationsController < ApplicationController
    include OwnerAuthentication

    skip_before_action :require_login
    layout "auth"
    rate_limit to: 8, within: 15.minutes, only: :create, by: -> { request.remote_ip },
               with: -> { render plain: "Too many attempts. Try again in a few minutes.", status: :too_many_requests }

    AUTH_PARAMS = %i[client_id redirect_uri response_type code_challenge code_challenge_method state scope resource].freeze

    def new
      return head(:not_found) unless Organizer.oauth_enabled?
      @auth = params.slice(*AUTH_PARAMS).permit(*AUTH_PARAMS).to_h
      @client = OauthFlow.validate_authorize!(@auth.symbolize_keys)
    rescue OauthFlow::Error => e
      @error = e.message
      render :error, status: :bad_request
    end

    def create
      @auth = params.slice(*AUTH_PARAMS).permit(*AUTH_PARAMS).to_h
      @client = OauthFlow.validate_authorize!(@auth.symbolize_keys)
      p = @auth.symbolize_keys
      if params[:decision] != "allow"
        return redirect_to OauthFlow.redirect_with(p[:redirect_uri], error: "access_denied", state: p[:state]), allow_other_host: true
      end
      unless signed_in? || OwnerAuthentication.password_matches?(params[:password])
        flash.now[:alert] = "Wrong password."
        return render :new, status: :unauthorized
      end
      code = OauthFlow.issue_code!(@client, p)
      redirect_to OauthFlow.redirect_with(p[:redirect_uri], code: code, state: p[:state]), allow_other_host: true
    rescue OauthFlow::Error => e
      @error = e.message
      render :error, status: :bad_request
    end
  end
end
