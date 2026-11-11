require "icalendar/tzinfo"

# Read-only iCalendar feed so phone and desktop calendars can subscribe.
module IcsFeed
  module_function

  def build(include_tasks: true)
    host = URI(Organizer.public_url).host || "life-organizer"
    cal = Icalendar::Calendar.new
    cal.prodid = "-//Life Organizer//EN"
    cal.append_custom_property("X-WR-CALNAME", "Life Organizer")
    cal.append_custom_property("X-WR-TIMEZONE", Time.zone.tzinfo.name)
    zones = {}

    cutoff = 180.days.ago
    events = Event.includes(:calendar, :task).joins(:calendar).where(calendars: { include_in_feed: true })
      .where("events.recurrence IS NOT NULL OR events.ends_at > ?", cutoff)
    events.find_each do |ev|
      tzid = ev.zone.tzinfo.name
      zones[tzid] ||= ev.zone.tzinfo
      title = ev.kind == "time_block" ? "[Focus] #{ev.display_title}" : ev.title
      cal.event do |e|
        e.uid = "event-#{ev.id}@#{host}"
        e.summary = title
        e.description = ev.description if ev.description.present?
        e.location = ev.location if ev.location.present?
        e.last_modified = Icalendar::Values::DateTime.new(ev.updated_at.utc, "tzid" => "UTC")
        if ev.all_day
          e.dtstart = Icalendar::Values::Date.new(ev.local_start.to_date)
          e.dtend = Icalendar::Values::Date.new(ev.local_end.to_date)
        else
          e.dtstart = Icalendar::Values::DateTime.new(ev.local_start, "tzid" => tzid)
          e.dtend = Icalendar::Values::DateTime.new(ev.local_end, "tzid" => tzid)
        end
        if ev.recurring?
          e.rrule = ev.recurrence
          ev.exdate_times.each do |t|
            e.append_exdate(ev.all_day ? Icalendar::Values::Date.new(t.to_date) : Icalendar::Values::DateTime.new(t, "tzid" => tzid))
          end
        end
        Array(ev.reminders).each do |minutes|
          e.alarm do |a|
            a.action = "DISPLAY"
            a.summary = title
            a.trigger = "-PT#{minutes}M"
          end
        end
      end
    end

    if include_tasks
      tzid = Time.zone.tzinfo.name
      Task.open_tasks.where.not(due_date: nil).find_each do |t|
        cal.event do |e|
          e.uid = "task-#{t.id}@#{host}"
          e.summary = "Due: #{t.title}"
          e.description = t.notes if t.notes.present?
          e.transp = "TRANSPARENT"
          if t.due_at
            zones[tzid] ||= Time.zone.tzinfo
            e.dtstart = Icalendar::Values::DateTime.new(t.due_at, "tzid" => tzid)
            e.dtend = Icalendar::Values::DateTime.new(t.due_at + 15.minutes, "tzid" => tzid)
          else
            e.dtstart = Icalendar::Values::Date.new(t.due_date)
            e.dtend = Icalendar::Values::Date.new(t.due_date + 1)
          end
        end
      end
    end

    zones.each_value { |tz| cal.add_timezone(tz.ical_timezone(Time.current)) }
    cal.publish
    cal.to_ical
  end
end
