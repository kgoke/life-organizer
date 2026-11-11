# Applies task attributes from the API, the MCP tools or the web forms.
# Only keys present in `attrs` change; nil (or "") clears a field.
class TaskWriter
  FIELDS = %w[title notes status priority due_date due_time estimate_minutes project_id project parent_id tags recurrence position].freeze

  def self.create!(attrs) = new(Task.new).apply!(attrs, creating: true)
  def self.update!(task, attrs) = new(task).apply!(attrs)

  def initialize(task)
    @task = task
  end

  # Returns [task, next_occurrence_or_nil].
  def apply!(attrs, creating: false)
    attrs = attrs.to_h.stringify_keys
    unknown = attrs.keys - FIELDS - %w[subtasks]
    raise Organizer::Invalid, "unknown field(s): #{unknown.join(', ')}" if unknown.any?
    was_done = @task.done?
    completing = attrs.key?("status") && attrs["status"] == "done" && !was_done

    attrs.each do |key, value|
      value = nil if value == ""
      case key
      when "subtasks" then next
      when "priority" then @task.priority_name = value
      when "due_date" then @task.due_date = TimeInput.parse_date(value, "due_date")
      when "project" then @task.project_id = resolve_project(value)
      when "project_id" then @task.project_id = value.presence && Project.find(value).id
      when "parent_id" then @task.parent_id = value.presence && value.to_i.positive? ? Task.find(value).id : nil
      when "status"
        raise Organizer::Invalid, "status: use one of #{Task::STATUSES.join(', ')}" unless value.nil? || Task::STATUSES.include?(value)
        @task.status = value if value && !completing
      when "notes" then @task.notes = value.to_s
      when "tags" then @task.tags = value || []
      when "position" then @task.position = value.to_i
      else @task.public_send("#{key}=", value)
      end
    end

    next_task = nil
    Task.transaction do
      @task.save!
      if creating
        Array(attrs["subtasks"]).each_with_index do |title, i|
          @task.subtasks.create!(title: title.to_s.strip, project_id: @task.project_id, position: i) if title.to_s.strip.present?
        end
      end
      next_task = @task.complete! if completing
    end
    [ @task.reload, next_task ]
  end

  private

  # A project id or name; unknown names are created.
  def resolve_project(value)
    return nil if value.blank?
    return Project.find(value).id if value.is_a?(Integer) || value.to_s.match?(/\A\d+\z/)
    (Project.find_by_name_ci(value) || Project.create!(name: value.to_s.strip)).id
  end
end
