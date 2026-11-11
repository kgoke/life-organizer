module JotsModule
  extend OrganizerModule

  self.module_name = "jots"
  self.description = "Quick notes jotted down to sort out later, which can be turned into tasks."
  nav "Jots", :jots_path, icon: "note"

  tool "list_jots", <<~DESC, kind: :read,
    List the owner's jots: quick notes they wrote down to sort out later, pinned first, then newest.
    When asked to tidy up or plan, offer to turn the ones that are really to-dos into tasks.
  DESC
    properties: { search: string("Text to find"), limit: integer("Max results, default 100") } do |a|
    scope = Jot.ordered
    scope = scope.where("body LIKE ?", "%#{Jot.sanitize_sql_like(a['search'].strip)}%") if a["search"].present?
    jots = scope.limit((a["limit"] || 100).to_i.clamp(1, 500))
    { count: jots.size, jots: jots.map(&:as_api_json) }
  end

  tool "add_jot", "Jot down a quick note for the owner to sort out later. Use create_task instead for a clear to-do.",
    properties: { body: string("The note. The first line works as its title."), pinned: boolean("Keep it at the top") },
    required: %w[body] do |a|
    Jot.create!(body: a["body"], pinned: a["pinned"] || false).as_api_json
  end

  tool "update_jot", "Change a jot's text or pin it.",
    properties: { jot_id: integer("Jot id"), body: string("New text"), pinned: boolean("Pin to the top") },
    required: %w[jot_id] do |a|
    jot = Jot.find(a["jot_id"])
    jot.update!(only_given(a, "body", "pinned"))
    jot.as_api_json
  end

  tool "convert_jot_to_task", <<~DESC,
    Turn a jot into a task. The jot's first line becomes the title and the rest the notes, unless
    you pass them. The jot is removed. Pass schedule_start (ISO date-time) to also time-block the
    new task on the calendar.
  DESC
    properties: {
      jot_id: integer("Jot id"), title: string("Task title (default: the jot's first line)"),
      notes: string("Task notes (default: the rest of the jot)"), due_date: string("YYYY-MM-DD"),
      due_time: string("HH:MM"), priority: string("Priority", enum: TasksModule::PRIORITY),
      project: string("Project name (created if new)"), tags: strings("Tags"),
      estimate_minutes: integer("Estimated minutes"),
      schedule_start: string("Also block time starting here, e.g. 2026-11-12T14:00"),
      duration_minutes: integer("Length of that time block (default: the estimate, or 30)")
    }, required: %w[jot_id] do |a|
    jot = Jot.find(a["jot_id"])
    fields = only_given(a, "title", "notes", "due_date", "due_time", "priority", "project", "tags", "estimate_minutes")
    task, block = jot.to_task!(fields, schedule_start: a["schedule_start"], duration_minutes: a["duration_minutes"])
    { task: task.reload.as_api_json, time_block: block&.as_api_json }
  end

  tool "delete_jot", "Delete a jot for good.", kind: :destructive,
    properties: { jot_id: integer("Jot id") }, required: %w[jot_id] do |a|
    jot = Jot.find(a["jot_id"])
    jot.destroy!
    { deleted: jot.id }
  end
end
