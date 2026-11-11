module Oauth
  # Discovery documents (RFC 9728 and RFC 8414) that tell Claude how to sign in.
  class MetadataController < ActionController::Base
    def protected_resource
      render json: {
        resource: "#{Organizer.public_url}/mcp",
        authorization_servers: [ Organizer.public_url ],
        scopes_supported: [ OauthFlow::SCOPE ],
        bearer_methods_supported: [ "header" ],
        resource_name: "Life Organizer"
      }
    end

    def authorization_server
      return head(:not_found) unless Organizer.oauth_enabled?
      base = Organizer.public_url
      render json: {
        issuer: base,
        authorization_endpoint: "#{base}/oauth/authorize",
        token_endpoint: "#{base}/oauth/token",
        registration_endpoint: "#{base}/oauth/register",
        revocation_endpoint: "#{base}/oauth/revoke",
        scopes_supported: [ OauthFlow::SCOPE ],
        response_types_supported: [ "code" ],
        grant_types_supported: %w[authorization_code refresh_token],
        code_challenge_methods_supported: [ "S256" ],
        token_endpoint_auth_methods_supported: %w[none client_secret_post client_secret_basic],
        revocation_endpoint_auth_methods_supported: %w[none client_secret_post client_secret_basic]
      }
    end
  end
end
