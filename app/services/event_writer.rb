# Applies event attributes from the API, the MCP tools or the web forms.
#
# start/end accept "2026-11-12T09:00" (read in the event's zone), ISO times with offsets, or
# plain dates for all-day events (end date exclusive). Without an end, duration_minutes is used.
# Moving only the start keeps the event's length.
class EventWriter
  FIELDS = %w[title description location calendar_id calendar start end duration_minutes all_day time_zone
              recurrence reminders color kind task_id].freeze
  DEFAULT_MINUTES = { "event" => 60, "time_block" => 30 }.freeze

  def self.create!(attrs) = new(Event.new(kind: "event")).apply!(attrs, creating: true)
  def self.update!(event, attrs) = new(event).apply!(attrs)

  # Change only one occurrence of a repeating event: it is split off as its own event.
  def self.update_occurrence!(event, occurrence, attrs)
    time = occurrence_time(event, occurrence)
    Event.transaction do
      single = event.dup
      single.recurrence = nil
      single.exdates = []
      single.starts_at = time
      single.ends_at = time + event.duration
      single.save!
      event.skip_occurrence!(time)
      new(single).apply!(attrs.to_h.except("recurrence", :recurrence))
    end
  end

  def self.delete_occurrence!(event, occurrence)
    event.skip_occurrence!(occurrence_time(event, occurrence))
  end

  def self.occurrence_time(event, value)
    raise Organizer::Invalid, "occurrence was given but this event does not repeat" unless event.recurring?
    time = if TimeInput.date_only?(value)
      d = TimeInput.parse_date(value, "occurrence")
      event.zone.local(d.year, d.month, d.day, event.local_start.hour, event.local_start.min)
    else
      TimeInput.parse_time(value, event.zone, "occurrence")
    end
    raise Organizer::Invalid, "#{value} is not an occurrence of event #{event.id}" unless event.occurrence?(time)
    time
  end

  def initialize(event)
    @event = event
  end

  def apply!(attrs, creating: false)
    attrs = attrs.to_h.stringify_keys
    unknown = attrs.keys - FIELDS
    raise Organizer::Invalid, "unknown field(s): #{unknown.join(', ')}" if unknown.any?
    attrs = attrs.transform_values { |v| v == "" ? nil : v }

    @event.kind = attrs["kind"] if creating && attrs["kind"]
    @event.time_zone = TimeInput.zone(attrs["time_zone"]).tzinfo.name if attrs["time_zone"] || creating
    raise Organizer::Invalid, "start is required" if creating && attrs["start"].blank?

    if creating || (attrs.keys & %w[start end duration_minutes all_day]).any?
      apply_times(attrs, creating)
    end

    @event.title = attrs["title"].to_s.strip if attrs.key?("title") && attrs["title"]
    @event.description = attrs["description"].to_s if attrs.key?("description")
    @event.location = attrs["location"].to_s if attrs.key?("location")
    @event.recurrence = attrs["recurrence"] if attrs.key?("recurrence")
    @event.exdates = [] if attrs.key?("recurrence") && attrs["recurrence"].blank?
    @event.reminders = attrs["reminders"] || [] if attrs.key?("reminders")
    @event.color = attrs["color"] if attrs.key?("color")
    @event.task_id = attrs["task_id"].presence && Task.find(attrs["task_id"]).id if attrs.key?("task_id")
    if attrs.key?("calendar_id") && attrs["calendar_id"]
      @event.calendar = Calendar.find(attrs["calendar_id"])
    elsif attrs.key?("calendar") && attrs["calendar"]
      @event.calendar = resolve_calendar(attrs["calendar"])
    end
    @event.calendar ||= Calendar.default
    @event.save!
    @event
  end

  private

  def apply_times(attrs, creating)
    zone = @event.zone
    current_minutes = creating ? nil : (@event.duration / 60).round
    all_day = attrs.key?("all_day") && !attrs["all_day"].nil? ? ActiveModel::Type::Boolean.new.cast(attrs["all_day"]) : nil
    start_raw = attrs["start"]
    all_day = TimeInput.date_only?(start_raw) if all_day.nil? && start_raw
    all_day = @event.all_day if all_day.nil?
    switching = !creating && all_day != @event.all_day

    start_raw ||= all_day ? @event.local_start.to_date.iso8601 : @event.local_start.iso8601
    minutes = attrs["duration_minutes"]&.to_i
    minutes ||= current_minutes unless attrs["end"] || switching

    if all_day
      day = TimeInput.parse_date(start_raw.to_s[0, 10], "start")
      starts = zone.local(day.year, day.month, day.day)
      ends = if attrs["end"]
        e = TimeInput.parse_date(attrs["end"].to_s[0, 10], "end")
        e <= day ? starts + 1.day : zone.local(e.year, e.month, e.day)
      else
        days = [ ((minutes || 1440) / 1440.0).round, 1 ].max
        (starts.to_date + days).in_time_zone(zone)
      end
    else
      start_raw = "#{start_raw}T09:00" if TimeInput.date_only?(start_raw)
      starts = TimeInput.parse_time(start_raw, zone, "start")
      ends = if attrs["end"]
        TimeInput.date_only?(attrs["end"]) ? TimeInput.parse_date(attrs["end"]).in_time_zone(zone) : TimeInput.parse_time(attrs["end"], zone, "end")
      else
        starts + (minutes || DEFAULT_MINUTES.fetch(@event.kind, 60)).minutes
      end
      raise Organizer::Invalid, "end must be after start" if ends <= starts
    end
    @event.all_day = all_day
    @event.starts_at = starts
    @event.ends_at = ends
  end

  def resolve_calendar(value)
    return Calendar.find(value) if value.is_a?(Integer) || value.to_s.match?(/\A\d+\z/)
    Calendar.where("lower(name) = ?", value.to_s.strip.downcase).first ||
      raise(Organizer::Invalid, "No calendar named #{value.inspect}. Use list_calendars to see them.")
  end
end
