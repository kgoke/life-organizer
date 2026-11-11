module Api
  # JSON API. Authenticate with `Authorization: Bearer <token>` (an API key or an OAuth
  # access token). The web app also calls it with its session cookie plus a CSRF token.
  class BaseController < ActionController::Base
    include OwnerAuthentication

    wrap_parameters false
    protect_from_forgery with: :exception, unless: -> { bearer_token.present? }
    before_action :authenticate!

    rescue_from ActiveRecord::RecordNotFound do |e|
      render json: { error: "#{e.model || 'Record'} not found" }, status: :not_found
    end
    rescue_from Organizer::Invalid, ArgumentError do |e|
      render json: { error: e.message }, status: :unprocessable_entity
    end
    rescue_from ActiveRecord::RecordInvalid do |e|
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
    rescue_from ActiveRecord::RecordNotDestroyed do |e|
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: e.message }, status: :bad_request
    end
    rescue_from ActionController::InvalidAuthenticityToken do
      render json: { error: "Missing or bad CSRF token" }, status: :unprocessable_entity
    end

    private

    def authenticate!
      @principal = bearer_token.present? ? token_principal : ("web" if signed_in?)
      return if @principal
      response.headers["WWW-Authenticate"] = 'Bearer realm="life-organizer"'
      render json: { error: "Not authenticated. Send 'Authorization: Bearer <api key>'." }, status: :unauthorized
    end

    # The JSON body (or form params) as a plain hash of the given keys.
    def body_params(*keys)
      raw = request.request_parameters.presence || params.to_unsafe_h
      raw = raw.to_h.stringify_keys
      keys.empty? ? raw : raw.slice(*keys.map(&:to_s))
    end

    def bool_param(name, default)
      return default unless params.key?(name)
      ActiveModel::Type::Boolean.new.cast(params[name])
    end
  end
end
