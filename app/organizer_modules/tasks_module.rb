module TasksModule
  extend OrganizerModule

  self.module_name = "tasks"
  self.description = "Tasks with subtasks, projects, tags, priorities, due dates and repeats."
  nav "Tasks", :tasks_path, icon: "check"

  PRIORITY = %w[none low medium high urgent].freeze
  STATUS = %w[todo in_progress done cancelled].freeze

  tool "list_tasks", <<~DESC, kind: :read,
    List tasks. Defaults to open tasks (to-do and in progress), soonest due first. Dates are
    YYYY-MM-DD. project is a project name or id. search matches title and notes.
    unscheduled_only returns tasks with no time block on the calendar yet. Each task includes its
    subtasks and time blocks.
  DESC
    properties: {
      status: string("open (default), all, todo, in_progress, done or cancelled", enum: %w[open all] + STATUS),
      project: string("Project name or id"), tag: string("Only tasks with this tag"),
      due_on: string("YYYY-MM-DD"), due_before: string("Due on or before, YYYY-MM-DD"),
      due_after: string("Due on or after, YYYY-MM-DD"), search: string("Text to find in title or notes"),
      unscheduled_only: boolean("Only tasks without a time block"), limit: integer("Max results, default 100")
    } do |a|
    filters = a.slice("status", "tag", "due_on", "due_before", "due_after").merge("q" => a["search"], "unscheduled" => a["unscheduled_only"], "limit" => a["limit"] || 100)
    if a["project"].present?
      project = a["project"].to_s.match?(/\A\d+\z/) ? Project.find(a["project"]) : Project.find_by_name_ci(a["project"])
      raise Organizer::Invalid, "No project named #{a['project'].inspect}" unless project
      filters["project_id"] = project.id
    end
    tasks = TaskQuery.call(filters)
    { count: tasks.size, tasks: tasks.map(&:as_api_json) }
  end

  tool "get_task", "Get one task with notes, subtasks and time blocks.", kind: :read,
    properties: { task_id: integer("Task id") }, required: %w[task_id] do |a|
    Task.find(a["task_id"]).as_api_json
  end

  TASK_FIELDS = {
    notes: string("Notes (markdown is fine)"),
    due_date: string("YYYY-MM-DD"),
    due_time: string("HH:MM, 24-hour, in the owner's time zone. Needs due_date."),
    priority: string("Priority", enum: PRIORITY),
    project: string("Project name (created if new) or id"),
    tags: strings("Tags, e.g. [\"errands\"]"),
    estimate_minutes: integer("How long it should take; used as the default time-block length"),
    recurrence: string("Repeat rule: RRULE like FREQ=WEEKLY;BYDAY=MO, or daily, weekdays, weekly, biweekly, monthly, yearly. Completing a repeating task creates the next one."),
    parent_id: integer("Make this a subtask of another task")
  }.freeze

  tool "create_task", "Create a task. Only title is required.",
    properties: { title: string("What needs doing") }.merge(TASK_FIELDS).merge(subtasks: strings("Titles of subtasks to create with it")),
    required: %w[title] do |a|
    task, = TaskWriter.create!(a.compact)
    task.as_api_json
  end

  tool "update_task", <<~DESC,
    Change a task. Only the fields you pass change. Pass an empty string to clear a field
    (due_date: "" removes the due date, project: "" removes the project; parent_id: 0 makes a
    subtask top-level). tags replaces the whole list. Setting status to done works like complete_task.
  DESC
    properties: { task_id: integer("Task id"), title: string("New title"), status: string("Status", enum: STATUS) }.merge(TASK_FIELDS),
    required: %w[task_id] do |a|
    attrs = only_given(a, *(TASK_FIELDS.keys + %i[title status]))
    attrs["parent_id"] = nil if attrs.key?("parent_id") && attrs["parent_id"].to_i.zero?
    task, nxt = TaskWriter.update!(Task.find(a["task_id"]), attrs)
    task.as_api_json.merge(next_occurrence: nxt&.as_api_json)
  end

  tool "complete_task", "Mark a task done. If it repeats, the next one is created and returned.",
    properties: { task_id: integer("Task id") }, required: %w[task_id] do |a|
    task = Task.find(a["task_id"])
    nxt = task.complete!
    { task: task.reload.as_api_json, next_occurrence: nxt&.as_api_json }
  end

  tool "delete_task", <<~DESC, kind: :destructive,
    Permanently delete a task with its subtasks and time blocks. Prefer complete_task, or status
    "cancelled", unless the owner asked to delete it.
  DESC
    properties: { task_id: integer("Task id") }, required: %w[task_id] do |a|
    task = Task.find(a["task_id"])
    task.destroy!
    { deleted: task.id, title: task.title }
  end

  tool "list_projects", "List projects (groups of tasks).", kind: :read do |_a|
    { projects: Project.active.ordered.map(&:as_api_json) }
  end

  tool "create_project", "Create a project.",
    properties: { name: string("Project name"), color: string("CSS color, e.g. #5b8def") }, required: %w[name] do |a|
    Project.create!(a.compact).as_api_json
  end
end
