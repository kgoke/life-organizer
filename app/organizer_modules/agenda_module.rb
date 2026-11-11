module AgendaModule
  extend OrganizerModule

  self.module_name = "agenda"
  self.description = "The daily plan across all modules."
  nav "Today", :root_path, icon: "sun"

  tool "get_agenda", <<~DESC, kind: :read,
    The owner's plan: for each day from date (default today) for `days` days, the events, time
    blocks and tasks due, plus overdue tasks. Also returns the current time, time zone and working
    hours. Start here for questions like "what's on today" or "plan my week".
  DESC
    properties: { date: string("First day, YYYY-MM-DD (default today)"), days: integer("Number of days, 1-31 (default 1)") } do |a|
    Agenda.build(TimeInput.parse_date(a["date"]), a["days"] || 1)
  end
end
