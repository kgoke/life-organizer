# One owner signs in with ADMIN_PASSWORD. Programs use a bearer token: an API key (lo_...)
# or an OAuth access token issued to a connected app such as Claude (loa_...).
module OwnerAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :signed_in? if respond_to?(:helper_method)
  end

  def signed_in?
    session[:owner_signed_in_at].present?
  end

  def sign_in!
    reset_session
    session[:owner_signed_in_at] = Time.current.to_i
  end

  def sign_out!
    reset_session
  end

  def bearer_token
    @bearer_token ||= begin
      header = request.authorization.to_s
      header.match?(/\ABearer /i) ? header.split(" ", 2).last.strip : request.headers["X-API-Key"].presence
    end
  end

  # Returns a label for the caller, or nil.
  def token_principal
    return nil if bearer_token.blank?
    if (key = ApiKey.authenticate(bearer_token))
      "api_key:#{key.name}"
    elsif (tok = OauthToken.authenticate_access(bearer_token))
      "oauth:#{tok.oauth_client.name}"
    end
  end

  def self.password_matches?(candidate)
    expected = Organizer.admin_password
    expected.present? && ActiveSupport::SecurityUtils.secure_compare(candidate.to_s, expected)
  end
end
