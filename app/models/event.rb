# A calendar event. kind "time_block" is calendar time reserved for working on a task.
#
# starts_at/ends_at are stored in UTC with the event's time_zone; local wall-clock times
# come from converting back, so a repeating 9:00 event stays at 9:00 across DST changes.
# All-day events start and end at local midnights (the end is exclusive).
class Event < ApplicationRecord
  KINDS = %w[event time_block].freeze
  MAX_OCCURRENCES = 2000

  belongs_to :calendar
  belongs_to :task, optional: true

  validates :title, presence: true, length: { maximum: 500 }
  validates :kind, inclusion: { in: KINDS }
  validate :ends_after_start
  validate :time_block_has_task

  before_save :compute_series_end

  # Rows that may have an occurrence overlapping [from, to). A day of padding covers
  # all-day events whose midnights are in another zone than the query.
  scope :overlapping_candidates, lambda { |from, to|
    pad = 1.day
    where("starts_at < ?", to + pad)
      .where("(recurrence IS NULL AND ends_at > :from) OR (recurrence IS NOT NULL AND (series_ends_at IS NULL OR series_ends_at > :from))", from: from - pad)
  }

  def zone = TimeInput.zone(time_zone)
  def local_start = starts_at.in_time_zone(zone)
  def local_end = ends_at.in_time_zone(zone)
  def duration = ends_at - starts_at
  def recurring? = recurrence.present?

  def recurrence=(value)
    super(Recurrence.normalize(value))
  end

  def reminders=(list)
    super(Array(list).map(&:to_i).select { |m| m.between?(0, 40_320) }.uniq.sort)
  end

  # Local start times of the occurrences that overlap [from, to).
  def occurrences_between(from, to)
    unless recurring?
      return local_start < to && local_end > from ? [ local_start ] : []
    end
    rule = Recurrence.rule(recurrence, local_start, zone.tzinfo.name, exdates: exdate_times)
    rule.between(from - duration, to, limit: MAX_OCCURRENCES).select { |s| s < to && s + duration > from }
  end

  def occurrence?(time)
    return false unless recurring?
    rule = Recurrence.rule(recurrence, local_start, zone.tzinfo.name)
    rule.between(time - 1, time + 1).any? { |t| t.to_i == time.to_i }
  end

  def exdate_times
    Array(exdates).map { |s| Time.iso8601(s).in_time_zone(zone) }
  end

  def skip_occurrence!(time)
    list = Array(exdates) | [ time.in_time_zone(zone).iso8601 ]
    update!(exdates: list.sort)
  end

  def display_title
    kind == "time_block" && task ? task.title : title
  end

  def display_color
    color.presence || calendar&.color
  end

  def as_api_json(occurrence_start: nil)
    s = occurrence_start || local_start
    e = s + duration
    json = {
      id: id, title: display_title, description: description, location: location,
      calendar_id: calendar_id, calendar: calendar&.name, color: display_color,
      start: format_time(s), end: format_time(e), all_day: all_day, time_zone: time_zone,
      recurrence: recurrence, recurring: recurring?, reminders: reminders, kind: kind,
      task_id: task_id, task_status: task&.status,
      created_at: created_at&.utc&.iso8601, updated_at: updated_at&.utc&.iso8601
    }
    if recurring?
      json[:occurrence] = s.iso8601
      json[:series_start] = format_time(local_start)
      json[:exdates] = exdates
    end
    json
  end

  private

  def format_time(t)
    all_day ? t.to_date.iso8601 : t.iso8601
  end

  def compute_series_end
    self.series_ends_at = if recurring?
      last = Recurrence.last_start(recurrence, local_start, zone.tzinfo.name)
      last && (last + duration)
    end
  end

  def ends_after_start
    errors.add(:ends_at, "must be after the start") if starts_at && ends_at && ends_at <= starts_at
  end

  def time_block_has_task
    errors.add(:task_id, "is required for a time block") if kind == "time_block" && task_id.blank?
  end
end
