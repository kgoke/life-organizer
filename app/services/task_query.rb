# Filters for listing tasks (REST API, MCP and the Tasks page).
module TaskQuery
  module_function

  def call(params)
    p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    p = p.stringify_keys
    scope = Task.includes(:project, :time_blocks, subtasks: [ :project, :time_blocks, { subtasks: %i[project time_blocks] } ])
    status = p["status"].presence || "open"
    case status
    when "open" then scope = scope.open_tasks
    when "all" then nil
    else
      raise Organizer::Invalid, "status: use open, all, #{Task::STATUSES.join(', ')}" unless Task::STATUSES.include?(status)
      scope = scope.where(status: status)
    end
    scope = scope.where(project_id: p["project_id"]) if p["project_id"].present?
    scope = scope.tagged(p["tag"]) if p["tag"].present?
    scope = scope.where(due_date: TimeInput.parse_date(p["due_on"], "due_on")) if p["due_on"].present?
    scope = scope.where("due_date <= ?", TimeInput.parse_date(p["due_before"], "due_before")) if p["due_before"].present?
    scope = scope.where("due_date >= ?", TimeInput.parse_date(p["due_after"], "due_after")) if p["due_after"].present?
    if p["q"].present?
      like = "%#{Task.sanitize_sql_like(p['q'].strip)}%"
      scope = scope.where("tasks.title LIKE :q OR tasks.notes LIKE :q", q: like)
    end
    if p["parent_id"].present?
      scope = scope.where(parent_id: p["parent_id"])
    elsif p["q"].blank? && p["top_level_only"].to_s != "false"
      scope = scope.top_level
    end
    scope = scope.unscheduled if ActiveModel::Type::Boolean.new.cast(p["unscheduled"])
    limit = (p["limit"].presence || 200).to_i.clamp(1, 1000)
    scope.agenda_order.limit(limit).offset(p["offset"].to_i)
  end
end
