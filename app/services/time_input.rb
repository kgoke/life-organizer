# Parses the date/time strings the API and MCP tools accept.
#
#   "2026-11-12"              -> a date (all-day)
#   "2026-11-12T09:00"        -> 9:00 in the given zone (the app zone by default)
#   "2026-11-12T14:00:00Z"    -> that instant, shown in the given zone
module TimeInput
  module_function

  DATE_ONLY = /\A\d{4}-\d{2}-\d{2}\z/

  def date_only?(value)
    value.is_a?(Date) && !value.is_a?(DateTime) || value.to_s.strip.match?(DATE_ONLY)
  end

  def zone(name = nil)
    return Time.zone if name.blank?
    ActiveSupport::TimeZone[name] || raise(Organizer::Invalid, "time_zone: unknown zone #{name.inspect}")
  end

  def parse_date(value, field = "date")
    return nil if value.blank?
    return value if value.is_a?(Date) && !value.is_a?(DateTime)
    Date.iso8601(value.to_s.strip[0, 10])
  rescue ArgumentError, Date::Error
    raise Organizer::Invalid, "#{field}: expected YYYY-MM-DD, got #{value.inspect}"
  end

  def parse_time(value, zone = Time.zone, field = "time")
    return value.in_time_zone(zone) if value.respond_to?(:in_time_zone) && !value.is_a?(String) && !value.is_a?(Date)
    text = value.to_s.strip
    raise Organizer::Invalid, "#{field}: expected an ISO 8601 date-time, got #{value.inspect}" unless text.match?(/\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/)
    # Time.zone.iso8601 keeps explicit offsets and reads naive times in the zone.
    zone.iso8601(text.sub(" ", "T")).change(usec: 0)
  rescue ArgumentError
    raise Organizer::Invalid, "#{field}: expected an ISO 8601 date-time, got #{value.inspect}"
  end

  def parse_clock(value, field = "due_time")
    return nil if value.blank?
    text = value.to_s.strip
    m = text.match(/\A(\d{1,2}):(\d{2})(?::\d{2})?\z/)
    raise Organizer::Invalid, "#{field}: expected HH:MM, got #{value.inspect}" unless m && m[1].to_i < 24 && m[2].to_i < 60
    format("%02d:%02d", m[1].to_i, m[2].to_i)
  end

  # A [start, end) range in UTC from dates or date-times (dates are whole days in the app zone).
  def range(start_value, end_value, default_days: 7)
    starts = if start_value.blank?
      Time.zone.today.beginning_of_day
    elsif date_only?(start_value)
      parse_date(start_value, "start").in_time_zone
    else
      parse_time(start_value, Time.zone, "start")
    end
    ends = if end_value.blank?
      starts + default_days.days
    elsif date_only?(end_value)
      parse_date(end_value, "end").in_time_zone
    else
      parse_time(end_value, Time.zone, "end")
    end
    raise Organizer::Invalid, "end must be after start" if ends <= starts
    raise Organizer::Invalid, "range is too long (max 800 days)" if ends - starts > 800.days
    [ starts, ends ]
  end
end
