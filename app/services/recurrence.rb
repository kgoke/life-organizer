# RFC 5545 recurrence rules, shared by tasks and events.
module Recurrence
  module_function

  ALIASES = {
    "daily" => "FREQ=DAILY",
    "weekdays" => "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
    "weekly" => "FREQ=WEEKLY",
    "biweekly" => "FREQ=WEEKLY;INTERVAL=2",
    "monthly" => "FREQ=MONTHLY",
    "yearly" => "FREQ=YEARLY"
  }.freeze

  # Accepts an alias ("weekly"), "RRULE:..." or a bare rule. Returns a bare rule or nil.
  def normalize(value)
    return nil if value.blank?
    text = value.to_s.strip
    return ALIASES[text.downcase] if ALIASES.key?(text.downcase)
    text = text.sub(/\ARRULE:/i, "").upcase
    raise Organizer::Invalid, "recurrence: the rule needs a FREQ, e.g. FREQ=WEEKLY;BYDAY=MO" unless text.include?("FREQ=")
    RRule::Rule.new(text, dtstart: Time.zone.now).from(Time.zone.now, limit: 1)
    text
  rescue RRule::InvalidRRule, ArgumentError, NoMethodError => e
    raise Organizer::Invalid, "recurrence: not a valid RRULE (#{e.message}). Example: FREQ=WEEKLY;BYDAY=MO,WE"
  end

  def bounded?(rule)
    rule.include?("COUNT=") || rule.include?("UNTIL=")
  end

  def rule(rule, dtstart, time_zone, exdates: [])
    RRule::Rule.new(rule, dtstart: dtstart, tzid: time_zone, exdate: exdates)
  end

  # Start of the last occurrence of a bounded rule, or nil if it repeats forever.
  def last_start(rule_text, dtstart, time_zone)
    return nil unless bounded?(rule_text)
    rule(rule_text, dtstart, time_zone).all(limit: 10_000).last
  end
end
