class OauthToken < ApplicationRecord
  ACCESS_TTL = 8.hours
  REFRESH_TTL = 90.days

  belongs_to :oauth_client
  scope :live, -> { where(revoked_at: nil) }

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  # Returns [record, access_token, refresh_token].
  def self.issue!(client, scope:, resource:)
    access = "loa_" + SecureRandom.urlsafe_base64(32)
    refresh = "lor_" + SecureRandom.urlsafe_base64(40)
    record = create!(
      oauth_client: client, access_digest: digest(access), refresh_digest: digest(refresh), scope: scope,
      resource: resource, access_expires_at: ACCESS_TTL.from_now, refresh_expires_at: REFRESH_TTL.from_now
    )
    [ record, access, refresh ]
  end

  def self.authenticate_access(raw)
    return nil unless raw.to_s.start_with?("loa_")
    live.where("access_expires_at > ?", Time.current).find_by(access_digest: digest(raw))
  end

  def self.find_refresh(raw)
    live.where("refresh_expires_at > ?", Time.current).find_by(refresh_digest: digest(raw))
  end

  def revoke! = update!(revoked_at: Time.current)
end
