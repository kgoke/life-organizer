# Settings read from the environment. See .env.example.

module Organizer
  # Raised for input that is well-formed JSON but makes no sense (bad date, end before start...).
  class Invalid < StandardError; end
  def self.public_url
    ENV.fetch("PUBLIC_URL", "http://localhost:3000").chomp("/")
  end

  def self.admin_password
    ENV.fetch("ADMIN_PASSWORD", "")
  end

  def self.day_start
    ENV.fetch("DAY_START", "08:00")
  end

  def self.day_end
    ENV.fetch("DAY_END", "18:00")
  end

  def self.oauth_enabled?
    ENV.fetch("OAUTH_ENABLED", "true") != "false"
  end
end
