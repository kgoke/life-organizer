class OauthAuthorizationCode < ApplicationRecord
  TTL = 5.minutes
  belongs_to :oauth_client
end
