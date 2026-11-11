# Lists events in a range, expanding repeating events into occurrences.
module CalendarQuery
  module_function

  # Returns [[event, local_occurrence_start], ...] sorted by start (all-day first on a day).
  def occurrences(from, to, calendar_id: nil, kind: nil, task_id: nil, query: nil)
    scope = Event.includes(:calendar, :task).overlapping_candidates(from, to)
    scope = scope.where(calendar_id: calendar_id) if calendar_id
    scope = scope.where(kind: kind) if kind.present?
    scope = scope.where(task_id: task_id) if task_id
    if query.present?
      like = "%#{Event.sanitize_sql_like(query.strip)}%"
      scope = scope.where("title LIKE :q OR description LIKE :q OR location LIKE :q", q: like)
    end
    pairs = scope.flat_map { |ev| ev.occurrences_between(from, to).map { |s| [ ev, s ] } }
    pairs.sort_by { |ev, s| [ s.to_i, ev.all_day ? 0 : 1, ev.id ] }
  end

  def events(from, to, **filters)
    occurrences(from, to, **filters).map { |ev, s| ev.as_api_json(occurrence_start: ev.recurring? ? s : nil) }
  end

  # Open slots between timed events and time blocks on a day, within working hours.
  def free_slots(day, day_start: nil, day_end: nil, min_minutes: 30)
    zone = Time.zone
    ws = clock_on(day, day_start || Organizer.day_start, zone)
    we = clock_on(day, day_end || Organizer.day_end, zone)
    raise Organizer::Invalid, "day_end must be after day_start" if we <= ws
    if day == zone.today
      now = zone.now.change(sec: 0)
      now += ((15 - now.min % 15) % 15).minutes
      ws = [ ws, now ].max
    end
    busy = occurrences(ws, we).reject { |ev, _| ev.all_day }.map { |ev, s| [ s, s + ev.duration ] }.sort_by(&:first)
    slots = []
    cursor = ws
    busy.each do |b_start, b_end|
      slots << [ cursor, [ b_start, we ].min ] if b_start > cursor && (b_start - cursor) >= min_minutes.minutes
      cursor = [ cursor, b_end ].max
      break if cursor >= we
    end
    slots << [ cursor, we ] if we > cursor && (we - cursor) >= min_minutes.minutes
    slots.select { |a, b| b > a }.map { |a, b| { start: a.iso8601, end: b.iso8601, minutes: ((b - a) / 60).round } }
  end

  def clock_on(day, clock, zone)
    h, m = TimeInput.parse_clock(clock, "working hours").split(":").map(&:to_i)
    zone.local(day.year, day.month, day.day, h, m)
  end

  # Reserve calendar time for a task.
  def schedule_task!(task, start:, end_time: nil, duration_minutes: nil, calendar: nil)
    raise Organizer::Invalid, "start needs a time for a time block, e.g. 2026-11-12T09:00" if TimeInput.date_only?(start)
    minutes = duration_minutes.presence || task.estimate_minutes || EventWriter::DEFAULT_MINUTES["time_block"]
    attrs = { "title" => task.title, "start" => start, "kind" => "time_block", "task_id" => task.id, "all_day" => false }
    end_time.present? ? attrs["end"] = end_time : attrs["duration_minutes"] = minutes
    attrs["calendar"] = calendar if calendar.present?
    EventWriter.create!(attrs)
  end
end
