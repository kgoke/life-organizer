# A quick note: something jotted down to deal with later. A jot can become a task, and its
# first line becomes the title and the rest the task's notes.
class Jot < ApplicationRecord
  validates :body, presence: true, length: { maximum: 20_000 }

  scope :ordered, -> { order(pinned: :desc, updated_at: :desc) }

  before_validation { self.body = body.to_s.gsub("\r\n", "\n").strip }

  def title_line
    body.lines.first.to_s.strip.truncate(200)
  end

  def rest
    body.lines.drop(1).join.strip
  end

  # Turns the jot into a task (and, with schedule_start, a time block for it), then deletes the
  # jot. attrs may override any task field, such as title or due_date.
  # Returns [task, time_block or nil].
  def to_task!(attrs = {}, schedule_start: nil, duration_minutes: nil)
    attrs = attrs.to_h.stringify_keys
    attrs["title"] = title_line if attrs["title"].blank?
    attrs["notes"] = rest if !attrs.key?("notes") && rest.present?
    transaction do
      task, = TaskWriter.create!(attrs)
      block = schedule_start.present? ? CalendarQuery.schedule_task!(task, start: schedule_start, duration_minutes: duration_minutes) : nil
      destroy!
      [ task, block ]
    end
  end

  def as_api_json
    { id: id, body: body, title: title_line, pinned: pinned, created_at: created_at.utc.iso8601, updated_at: updated_at.utc.iso8601 }
  end
end
