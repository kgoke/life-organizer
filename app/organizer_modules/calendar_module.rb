module CalendarModule
  extend OrganizerModule

  self.module_name = "calendar"
  self.description = "Calendars, events with repeats and reminders, time blocks for tasks, and an ICS feed."
  nav "Calendar", :calendar_path, icon: "calendar"

  TIME_HELP = "ISO 8601: '2026-11-12T09:00' (no offset = the owner's time zone) or '2026-11-12' for all-day."

  tool "list_events", <<~DESC, kind: :read,
    List calendar events between start and end (dates or ISO date-times; end is exclusive).
    Defaults to the next 7 days. Repeating events come back once per occurrence with
    `occurrence` set; pass it to update_event or delete_event to change just that one. Time
    blocks (kind "time_block") are time reserved for a task.
  DESC
    properties: {
      start: string("Range start, date or date-time (default today)"),
      end: string("Range end, exclusive (default start + 7 days)"),
      calendar: string("Calendar name or id"), search: string("Text in title, description or location"),
      include_time_blocks: boolean("Default true")
    } do |a|
    from, to = TimeInput.range(a["start"], a["end"])
    cal = a["calendar"].present? ? calendar_for(a["calendar"]) : nil
    events = CalendarQuery.events(from, to, calendar_id: cal&.id, query: a["search"])
    events.reject! { |e| e[:kind] == "time_block" } if a["include_time_blocks"] == false
    { time_zone: Time.zone.tzinfo.name, count: events.size, events: events }
  end

  tool "get_event", "Get one event (the whole series for a repeating event).", kind: :read,
    properties: { event_id: integer("Event id") }, required: %w[event_id] do |a|
    Event.find(a["event_id"]).as_api_json
  end

  EVENT_FIELDS = {
    end: string("#{TIME_HELP} All-day end dates are exclusive (a one-day event on the 12th ends on the 13th)."),
    duration_minutes: integer("Length when end is omitted (default 60)"),
    all_day: boolean("Inferred from a date-only start if omitted"),
    description: string("Details"), location: string("Where"),
    calendar: string("Calendar name or id (default calendar if omitted)"),
    recurrence: string("Repeat rule: RRULE like FREQ=WEEKLY;BYDAY=TU,TH, or daily, weekdays, weekly, biweekly, monthly, yearly"),
    reminders: integers("Minutes before start, e.g. [10, 60]")
  }.freeze

  tool "create_event", <<~DESC,
    Create a calendar event. If end is omitted, duration_minutes is used (default 60). To reserve
    time for a task, use schedule_task instead.
  DESC
    properties: { title: string("Event title"), start: string(TIME_HELP) }.merge(EVENT_FIELDS)
      .merge(time_zone: string("IANA zone like America/New_York; defaults to the owner's")),
    required: %w[title start] do |a|
    EventWriter.create!(a.compact).as_api_json
  end

  tool "update_event", <<~DESC,
    Change an event or time block. Only the fields you pass change; an empty string clears
    description, location or recurrence. Moving start keeps the same length unless end or
    duration_minutes is given. For a repeating event, pass occurrence (from list_events) to change
    only that one (it becomes its own event, which is returned); without it the whole series changes.
  DESC
    properties: {
      event_id: integer("Event id"), occurrence: string("Start of the one occurrence to change"),
      title: string("New title"), start: string(TIME_HELP)
    }.merge(EVENT_FIELDS),
    required: %w[event_id] do |a|
    event = Event.find(a["event_id"])
    attrs = only_given(a, :title, :start, *EVENT_FIELDS.keys)
    result = a["occurrence"].present? ? EventWriter.update_occurrence!(event, a["occurrence"], attrs) : EventWriter.update!(event, attrs)
    result.as_api_json
  end

  tool "delete_event", <<~DESC, kind: :destructive,
    Delete an event or time block. For a repeating event, pass occurrence to skip only that one;
    without it the whole series is deleted.
  DESC
    properties: { event_id: integer("Event id"), occurrence: string("Start of the one occurrence to skip") },
    required: %w[event_id] do |a|
    event = Event.find(a["event_id"])
    if a["occurrence"].present?
      EventWriter.delete_occurrence!(event, a["occurrence"])
    else
      event.destroy!
    end
    { deleted: event.id, title: event.display_title, occurrence: a["occurrence"].presence }
  end

  tool "schedule_task", <<~DESC,
    Time-block a task: reserve calendar time to work on it. start is an ISO date-time such as
    2026-11-12T09:00. The length comes from end, else duration_minutes, else the task's
    estimate_minutes, else 30 minutes. Use find_free_time first to pick an open slot. Move or
    resize a block with update_event; remove it with delete_event.
  DESC
    properties: {
      task_id: integer("Task id"), start: string("ISO date-time"), duration_minutes: integer("Length in minutes"),
      end: string("ISO date-time"), calendar: string("Calendar name or id")
    },
    required: %w[task_id start] do |a|
    CalendarQuery.schedule_task!(Task.find(a["task_id"]), start: a["start"], end_time: a["end"],
                                 duration_minutes: a["duration_minutes"], calendar: a["calendar"]).as_api_json
  end

  tool "find_free_time", <<~DESC, kind: :read,
    Open slots on a day between events and time blocks, within working hours. For today, slots
    start from now.
  DESC
    properties: {
      date: string("YYYY-MM-DD, default today"), min_minutes: integer("Shortest useful slot, default 30"),
      day_start: string("HH:MM, default from settings"), day_end: string("HH:MM, default from settings")
    } do |a|
    day = TimeInput.parse_date(a["date"]) || Time.zone.today
    slots = CalendarQuery.free_slots(day, day_start: a["day_start"], day_end: a["day_end"], min_minutes: (a["min_minutes"] || 30).to_i.clamp(5, 1440))
    { date: day.iso8601, time_zone: Time.zone.tzinfo.name, free: slots }
  end

  tool "list_calendars", "List calendars. Events go to the default calendar unless one is named.", kind: :read do |_a|
    Calendar.default
    { calendars: Calendar.order(:id).map(&:as_api_json) }
  end

  tool "create_calendar", "Create a calendar (e.g. Work, Family).",
    properties: { name: string("Calendar name"), color: string("CSS color, e.g. #e8833a") }, required: %w[name] do |a|
    Calendar.create!(a.compact).as_api_json
  end

  def self.calendar_for(value)
    return Calendar.find(value) if value.to_s.match?(/\A\d+\z/)
    Calendar.where("lower(name) = ?", value.to_s.strip.downcase).first || raise(Organizer::Invalid, "No calendar named #{value.inspect}")
  end
end
