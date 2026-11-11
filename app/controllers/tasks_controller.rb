class TasksController < ApplicationController
  FILTERS = %w[open today upcoming someday done].freeze

  def index
    @filter = FILTERS.include?(params[:filter]) ? params[:filter] : "open"
    query = { "q" => params[:q], "project_id" => params[:project_id], "tag" => params[:tag], "limit" => 500 }
    case @filter
    when "today" then query.merge!("status" => "open", "due_before" => Time.zone.today.iso8601)
    when "upcoming" then query.merge!("status" => "open", "due_after" => (Time.zone.today + 1).iso8601)
    when "someday" then query["status"] = "open"
    when "done" then query["status"] = "done"
    else query["status"] = "open"
    end
    @tasks = TaskQuery.call(query)
    @tasks = @tasks.where(due_date: nil) if @filter == "someday"
    @tasks = @tasks.reorder(completed_at: :desc) if @filter == "done"
    @projects = Project.active.ordered
    @tags = Task.open_tasks.pluck(:tags).flatten.uniq.sort_by(&:downcase)
  end

  def show
    redirect_to edit_task_path(params[:id])
  end

  def create
    task, = TaskWriter.create!(task_params)
    redirect_back fallback_location: tasks_path, notice: "Added “#{task.title}”."
  end

  def edit
    @task = Task.includes(:subtasks, :time_blocks, :project).find(params[:id])
    @projects = Project.active.ordered
  end

  def update
    task = Task.find(params[:id])
    _task, nxt = TaskWriter.update!(task, task_params)
    notice = nxt ? "Done. The next one is due #{I18n.l(nxt.due_date, format: :long)}." : "Saved."
    redirect_to(params[:return_to].presence || edit_task_path(task), notice: notice)
  end

  def toggle
    task = Task.find(params[:id])
    if task.done?
      task.reopen!
      notice = nil
    else
      nxt = task.complete!
      notice = nxt ? "Nice. Next one is due #{I18n.l(nxt.due_date, format: :long)}." : nil
    end
    redirect_back fallback_location: tasks_path, notice: notice
  end

  def destroy
    task = Task.find(params[:id])
    parent = task.parent
    task.destroy!
    redirect_to parent ? edit_task_path(parent) : tasks_path, notice: "Deleted “#{task.title}”.", status: :see_other
  end

  private

  def task_params
    permitted = params.require(:task).permit(:title, :notes, :status, :priority, :due_date, :due_time, :estimate_minutes,
                                             :project_id, :parent_id, :tags, :recurrence, :recurrence_custom).to_h
    if permitted.key?("recurrence_custom")
      custom = permitted.delete("recurrence_custom")
      permitted["recurrence"] = custom if permitted["recurrence"] == "custom"
    end
    permitted["tags"] = permitted["tags"].split(",") if permitted["tags"].is_a?(String)
    permitted["estimate_minutes"] = permitted["estimate_minutes"].presence&.to_i if permitted.key?("estimate_minutes")
    permitted
  end
end
