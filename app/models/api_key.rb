# A long-lived key for scripts and MCP clients that can send a header (e.g. Claude Code).
# Only a SHA-256 digest is stored; the key is shown once when created.
class ApiKey < ApplicationRecord
  PREFIX = "lo_".freeze

  validates :name, presence: true, length: { maximum: 100 }
  scope :active, -> { where(revoked_at: nil) }

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  # Returns [record, raw_key].
  def self.generate!(name)
    raw = PREFIX + SecureRandom.urlsafe_base64(32)
    [ create!(name: name.presence || "API key", prefix: raw[0, 10], token_digest: digest(raw)), raw ]
  end

  def self.authenticate(raw)
    return nil unless raw.to_s.start_with?(PREFIX)
    key = active.find_by(token_digest: digest(raw))
    key&.update_column(:last_used_at, Time.current)
    key
  end

  def revoke! = update!(revoked_at: Time.current)

  def as_api_json
    { id: id, name: name, prefix: prefix, created_at: created_at.utc.iso8601, last_used_at: last_used_at&.utc&.iso8601 }
  end
end
