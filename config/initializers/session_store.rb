# Signed-in sessions last 30 days.
Rails.application.config.session_store :cookie_store, key: "_life_organizer_session", expire_after: 30.days,
  same_site: :lax, secure: ENV["FORCE_SSL"] == "true" || ENV.fetch("PUBLIC_URL", "").start_with?("https://")
