class AppSetting < ApplicationRecord
  def self.get(key) = find_by(key: key)&.value

  def self.set(key, value)
    row = find_or_initialize_by(key: key)
    row.update!(value: value)
    value
  end

  def self.feed_token(regenerate: false)
    token = get("ics_feed_token")
    token = set("ics_feed_token", SecureRandom.urlsafe_base64(24)) if token.blank? || regenerate
    token
  end
end
