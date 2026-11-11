# The day's plan across modules: events, time blocks, tasks due and overdue tasks.
module Agenda
  module_function

  def build(first_day = nil, days = 1)
    first_day ||= Time.zone.today
    days = days.to_i.clamp(1, 31)
    out = (0...days).map do |i|
      day = first_day + i
      from = day.in_time_zone
      events = CalendarQuery.events(from, from + 1.day)
      due = Task.open_tasks.where(due_date: day).includes(:project).agenda_order
      {
        date: day.iso8601, weekday: day.strftime("%A"),
        events: events.select { |e| e[:kind] == "event" },
        time_blocks: events.select { |e| e[:kind] == "time_block" },
        tasks_due: due.map { |t| t.as_api_json(depth: 0) }
      }
    end
    result = {
      now: Time.zone.now.change(usec: 0).iso8601, time_zone: Time.zone.tzinfo.name,
      working_hours: { start: Organizer.day_start, end: Organizer.day_end }, days: out
    }
    if first_day <= Time.zone.today
      result[:overdue_tasks] = Task.open_tasks.where("due_date < ?", Time.zone.today).includes(:project).agenda_order.map { |t| t.as_api_json(depth: 0) }
    end
    result
  end
end
