class EventsController < ApplicationController
  def new
    all_day = %w[true 1].include?(params[:all_day]) || TimeInput.date_only?(params[:start])
    start = new_event_time(params[:start]) || Time.zone.now.beginning_of_hour + 1.hour
    finish = new_event_time(params[:end]) || start + (all_day ? 1.day : 1.hour)
    @event = Event.new(starts_at: start, ends_at: finish, all_day: all_day, time_zone: Time.zone.tzinfo.name,
                       calendar: Calendar.default, kind: "event")
    @calendars = Calendar.order(:id)
  end

  def create
    EventWriter.create!(event_params)
    redirect_to calendar_path(date: event_params["start"].to_s[0, 10]), notice: "Event added."
  end

  def edit
    @event = Event.includes(:task, :calendar).find(params[:id])
    @occurrence = params[:occurrence].presence
    @occurrence_start = @occurrence ? EventWriter.occurrence_time(@event, @occurrence) : @event.local_start
    @calendars = Calendar.order(:id)
  end

  def update
    event = Event.find(params[:id])
    attrs = event_params
    if params[:occurrence].present? && params[:scope] != "all"
      EventWriter.update_occurrence!(event, params[:occurrence], attrs)
    else
      if params[:occurrence].present?
        # Editing the series from one occurrence: shift the series by the same amount.
        occ = EventWriter.occurrence_time(event, params[:occurrence])
        attrs = shift_series(event, occ, attrs)
      end
      EventWriter.update!(event, attrs)
    end
    redirect_to calendar_path(date: attrs["start"].to_s[0, 10]), notice: "Saved."
  end

  def destroy
    event = Event.find(params[:id])
    if params[:occurrence].present? && params[:scope] != "all"
      EventWriter.delete_occurrence!(event, params[:occurrence])
    else
      event.destroy!
    end
    redirect_to calendar_path, notice: "Deleted.", status: :see_other
  end

  private

  def event_params
    p = params.require(:event).permit(:title, :description, :location, :calendar_id, :start, :end, :all_day,
                                      :recurrence, :recurrence_custom, :reminders, :color).to_h
    custom = p.delete("recurrence_custom")
    p["recurrence"] = custom if p["recurrence"] == "custom"
    p["reminders"] = p["reminders"].to_s.split(/[\s,]+/).reject(&:blank?).map(&:to_i) if p.key?("reminders")
    p["all_day"] = p["all_day"] == "1" if p.key?("all_day")
    if p["all_day"]
      p["start"] = p["start"].to_s[0, 10] if p["start"]
      # The form shows an inclusive last day; the model stores an exclusive end.
      p["end"] = (TimeInput.parse_date(p["end"].to_s[0, 10]) + 1).iso8601 if p["end"].present?
    end
    p
  end

  def new_event_time(value)
    return nil if value.blank?
    return TimeInput.parse_date(value).in_time_zone if TimeInput.date_only?(value)
    TimeInput.parse_time(value)
  end

  def shift_series(event, occurrence, attrs)
    return attrs if attrs["start"].blank? || attrs["all_day"]
    new_start = TimeInput.parse_time(attrs["start"], event.zone)
    delta = new_start - occurrence
    length = attrs["end"].present? ? TimeInput.parse_time(attrs["end"], event.zone) - new_start : event.duration
    series_start = event.local_start + delta
    attrs.merge("start" => series_start.iso8601, "end" => (series_start + length).iso8601)
  end
end
