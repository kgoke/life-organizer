class Task < ApplicationRecord
  STATUSES = %w[todo in_progress done cancelled].freeze
  OPEN_STATUSES = %w[todo in_progress].freeze
  PRIORITIES = %w[none low medium high urgent].freeze

  belongs_to :project, optional: true
  belongs_to :parent, class_name: "Task", optional: true, inverse_of: :subtasks
  has_many :subtasks, -> { order(:position, :id) }, class_name: "Task", foreign_key: :parent_id,
           dependent: :destroy, inverse_of: :parent
  has_many :time_blocks, -> { where(kind: "time_block").order(:starts_at) }, class_name: "Event", dependent: :destroy

  validates :title, presence: true, length: { maximum: 500 }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: 0..4 }
  validates :estimate_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 1440 }, allow_nil: true
  validate :due_time_needs_date
  validate :parent_is_not_a_descendant

  before_save :track_completion

  scope :open_tasks, -> { where(status: OPEN_STATUSES) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :unscheduled, -> { where.not(id: Event.where(kind: "time_block").where.not(task_id: nil).select(:task_id)) }
  scope :agenda_order, lambda {
    order(Arel.sql("due_date IS NULL, due_date, due_time IS NULL, due_time, priority DESC, position, id"))
  }
  scope :tagged, ->(tag) { where("EXISTS (SELECT 1 FROM json_each(tasks.tags) WHERE lower(json_each.value) = lower(?))", tag) }

  def open? = OPEN_STATUSES.include?(status)
  def done? = status == "done"

  def overdue?
    open? && due_date.present? && due_date < Time.zone.today
  end

  def priority_name
    PRIORITIES[priority] || "none"
  end

  def priority_name=(name)
    value = PRIORITIES.index(name.to_s.presence || "none")
    raise Organizer::Invalid, "priority: use one of #{PRIORITIES.join(', ')}" unless value
    self.priority = value
  end

  def tags=(list)
    seen = []
    Array(list).flat_map { |t| t.to_s.split(",") }.each do |t|
      tag = t.strip.delete_prefix("#")
      seen << tag if tag.present? && seen.none? { |s| s.casecmp?(tag) }
    end
    super(seen)
  end

  def recurrence=(value)
    super(Recurrence.normalize(value))
  end

  def due_time=(value)
    super(TimeInput.parse_clock(value))
  end

  def due_at
    return nil unless due_date
    due_time ? Time.zone.parse("#{due_date} #{due_time}") : nil
  end

  # Marks the task done. For a repeating task, creates and returns the next one.
  def complete!
    return nil if done?
    transaction do
      update!(status: "done")
      spawn_next_occurrence!
    end
  end

  def reopen!
    update!(status: "todo")
  end

  def as_api_json(depth: 3, include_blocks: true)
    json = {
      id: id, title: title, notes: notes, status: status, priority: priority_name,
      due_date: due_date&.iso8601, due_time: due_time, estimate_minutes: estimate_minutes,
      project_id: project_id, project: project&.name, parent_id: parent_id, tags: tags,
      recurrence: recurrence, position: position, overdue: overdue?,
      completed_at: completed_at&.utc&.iso8601, created_at: created_at&.utc&.iso8601, updated_at: updated_at&.utc&.iso8601
    }
    json[:subtasks] = subtasks.map { |s| s.as_api_json(depth: depth - 1, include_blocks: include_blocks) } if depth.positive?
    if include_blocks
      json[:time_blocks] = time_blocks.map do |b|
        { event_id: b.id, start: b.local_start.iso8601, end: b.local_end.iso8601, recurring: b.recurring? }
      end
    end
    json
  end

  private

  def track_completion
    if status == "done"
      self.completed_at ||= Time.current
    else
      self.completed_at = nil
    end
  end

  def due_time_needs_date
    errors.add(:due_time, "needs a due_date") if due_time.present? && due_date.blank?
  end

  def parent_is_not_a_descendant
    return if parent_id.blank? || new_record?
    node = parent
    while node
      if node.id == id
        errors.add(:parent_id, "cannot be the task itself or one of its subtasks")
        break
      end
      node = node.parent
    end
  end

  # Schedule-based repeats: the next due date follows the rule from the old due date. If the
  # task was finished late, it jumps to the next date that is today or later.
  def spawn_next_occurrence!
    return nil if recurrence.blank?
    anchor = due_date || Time.zone.today
    after = [ anchor, Time.zone.today - 1 ].max
    rule = Recurrence.rule(recurrence, anchor.in_time_zone, Time.zone.tzinfo.name)
    next_start = rule.from(after.in_time_zone + 1.day, limit: 1).first
    return nil unless next_start
    copy = Task.create!(
      title: title, notes: notes, status: "todo", priority: priority, due_date: next_start.to_date, due_time: due_time,
      estimate_minutes: estimate_minutes, project_id: project_id, parent_id: parent_id, tags: tags,
      recurrence: recurrence, position: position
    )
    subtasks.each do |s|
      copy.subtasks.create!(title: s.title, notes: s.notes, priority: s.priority, estimate_minutes: s.estimate_minutes,
                            project_id: s.project_id, position: s.position, tags: s.tags)
    end
    update_column(:recurrence, nil) # the finished one keeps its history but no longer repeats
    copy
  end
end
