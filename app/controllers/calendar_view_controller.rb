class CalendarViewController < ApplicationController
  def show
    @unscheduled = Task.open_tasks.unscheduled.includes(:project).agenda_order.limit(100)
    @calendars = Calendar.order(:id)
    Calendar.default if @calendars.empty?
  end
end
