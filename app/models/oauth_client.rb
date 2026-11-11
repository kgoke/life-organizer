# A client registered through OAuth dynamic client registration (e.g. claude.ai).
class OauthClient < ApplicationRecord
  has_many :oauth_authorization_codes, dependent: :delete_all
  has_many :oauth_tokens, dependent: :delete_all

  validates :client_id, presence: true, uniqueness: true

  def redirect_uri_allowed?(uri) = Array(redirect_uris).include?(uri)
end
