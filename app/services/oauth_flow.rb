# OAuth 2.1 authorization-code flow with PKCE, plus dynamic client registration, so a
# claude.ai custom connector can connect: Claude registers itself, sends the owner to the
# consent page, and swaps the code for tokens. Access tokens last 8 hours; refresh tokens
# 90 days and rotate on every use.
module OauthFlow
  SCOPE = "organizer".freeze

  class Error < StandardError
    attr_reader :code

    def initialize(code, description)
      super(description)
      @code = code
    end
  end

  module_function

  def register!(meta)
    uris = Array(meta["redirect_uris"]).map(&:to_s)
    raise Error.new("invalid_redirect_uri", "redirect_uris is required") if uris.empty?
    uris.each do |u|
      uri = URI.parse(u)
      local = %w[localhost 127.0.0.1 [::1]].include?(uri.host)
      unless uri.scheme == "https" || (uri.scheme == "http" && local) || (uri.scheme.present? && !%w[http https javascript data].include?(uri.scheme))
        raise Error.new("invalid_redirect_uri", "redirect URIs must use https (or http on localhost)")
      end
    rescue URI::InvalidURIError
      raise Error.new("invalid_redirect_uri", "#{u} is not a valid URI")
    end
    method = meta["token_endpoint_auth_method"].presence || "none"
    raise Error.new("invalid_client_metadata", "unsupported token_endpoint_auth_method") unless %w[none client_secret_post client_secret_basic].include?(method)
    secret = method == "none" ? nil : SecureRandom.urlsafe_base64(32)
    client = OauthClient.create!(
      client_id: SecureRandom.uuid, name: meta["client_name"].presence || "Unnamed app", redirect_uris: uris,
      metadata: { "token_endpoint_auth_method" => method, "secret_digest" => secret && OauthToken.digest(secret),
                  "grant_types" => meta["grant_types"] || %w[authorization_code refresh_token] }
    )
    response = {
      client_id: client.client_id, client_name: client.name, redirect_uris: uris,
      token_endpoint_auth_method: method, grant_types: client.metadata["grant_types"], response_types: [ "code" ],
      client_id_issued_at: client.created_at.to_i
    }
    response.merge!(client_secret: secret, client_secret_expires_at: 0) if secret
    response
  end

  # Checks an authorization request; returns the client or raises.
  def validate_authorize!(p)
    client = OauthClient.find_by(client_id: p[:client_id]) || raise(Error.new("invalid_client", "Unknown app. Try connecting again."))
    raise Error.new("invalid_request", "redirect_uri is not registered for this app") unless client.redirect_uri_allowed?(p[:redirect_uri])
    raise Error.new("unsupported_response_type", "response_type must be code") unless p[:response_type] == "code"
    raise Error.new("invalid_request", "PKCE with S256 is required") unless p[:code_challenge].present? && p[:code_challenge_method] == "S256"
    client
  end

  def issue_code!(client, p)
    code = SecureRandom.urlsafe_base64(32)
    client.oauth_authorization_codes.create!(
      code_digest: OauthToken.digest(code), redirect_uri: p[:redirect_uri], code_challenge: p[:code_challenge],
      scope: p[:scope].presence || SCOPE, resource: p[:resource], expires_at: OauthAuthorizationCode::TTL.from_now
    )
    code
  end

  def redirect_with(uri, params)
    u = URI.parse(uri)
    query = URI.decode_www_form(u.query.to_s) + params.compact.map { |k, v| [ k.to_s, v.to_s ] }
    u.query = URI.encode_www_form(query)
    u.to_s
  end

  def authenticate_client!(params, authorization_header)
    id, secret = params[:client_id], params[:client_secret]
    if authorization_header.to_s.start_with?("Basic ")
      id, secret = Base64.decode64(authorization_header.split(" ", 2).last).split(":", 2).map { |s| CGI.unescape(s.to_s) }
    end
    client = OauthClient.find_by(client_id: id) || raise(Error.new("invalid_client", "unknown client"))
    digest = client.metadata["secret_digest"]
    if digest.present? && !ActiveSupport::SecurityUtils.secure_compare(OauthToken.digest(secret.to_s), digest)
      raise Error.new("invalid_client", "client authentication failed")
    end
    client
  end

  def exchange_code!(client, params)
    record = OauthAuthorizationCode.find_by(code_digest: OauthToken.digest(params[:code].to_s))
    raise Error.new("invalid_grant", "authorization code is not valid") if record.nil? || record.oauth_client_id != client.id
    raise Error.new("invalid_grant", "authorization code already used") if record.used_at
    raise Error.new("invalid_grant", "authorization code expired") if record.expires_at < Time.current
    raise Error.new("invalid_grant", "redirect_uri does not match") if params[:redirect_uri].present? && params[:redirect_uri] != record.redirect_uri
    verifier = params[:code_verifier].to_s
    challenge = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    raise Error.new("invalid_grant", "PKCE verification failed") unless verifier.present? && ActiveSupport::SecurityUtils.secure_compare(challenge, record.code_challenge)
    record.update!(used_at: Time.current)
    token_response(client, record.scope, record.resource)
  end

  def refresh!(client, params)
    token = OauthToken.find_refresh(params[:refresh_token])
    raise Error.new("invalid_grant", "refresh token is not valid") if token.nil? || token.oauth_client_id != client.id
    token.revoke!
    token_response(client, token.scope, token.resource)
  end

  def token_response(client, scope, resource)
    _record, access, refresh = OauthToken.issue!(client, scope: scope, resource: resource)
    { access_token: access, token_type: "Bearer", expires_in: OauthToken::ACCESS_TTL.to_i, refresh_token: refresh, scope: scope }
  end

  def revoke!(raw)
    digest = OauthToken.digest(raw)
    OauthToken.live.where(access_digest: digest).or(OauthToken.live.where(refresh_digest: digest)).find_each(&:revoke!)
  end
end
