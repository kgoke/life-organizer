class TodayController < ApplicationController
  def show
    @day = params[:date].present? ? TimeInput.parse_date(params[:date]) : Time.zone.today
    @agenda = Agenda.build(@day, 1)
    @schedule = CalendarQuery.occurrences(@day.in_time_zone, @day.in_time_zone + 1.day)
    @due = Task.open_tasks.where(due_date: @day).includes(:project, :time_blocks).agenda_order
    @overdue = @day == Time.zone.today ? Task.open_tasks.where("due_date < ?", @day).includes(:project).agenda_order : Task.none
    @done_today = Task.where(status: "done", completed_at: @day.in_time_zone.all_day).order(completed_at: :desc)
    @free = CalendarQuery.free_slots(@day, min_minutes: 30)
    @projects = Project.active.ordered
    @jots = Jot.ordered.limit(5)
    @jot_count = Jot.count
  end
end
