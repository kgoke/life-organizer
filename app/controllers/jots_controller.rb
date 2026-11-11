class JotsController < ApplicationController
  def index
    @jots = Jot.ordered
    @jots = @jots.where("body LIKE ?", "%#{Jot.sanitize_sql_like(params[:q].strip)}%") if params[:q].present?
    @projects = Project.active.ordered
  end

  def create
    Jot.create!(jot_params)
    redirect_back fallback_location: jots_path, notice: "Jotted."
  end

  def edit
    @jot = Jot.find(params[:id])
    @projects = Project.active.ordered
  end

  def update
    jot = Jot.find(params[:id])
    jot.update!(jot_params)
    redirect_to(params[:return_to].presence || jots_path, notice: ("Saved." unless jot.saved_change_to_pinned? && !jot.saved_change_to_body?))
  end

  def destroy
    Jot.find(params[:id]).destroy!
    redirect_back fallback_location: jots_path, notice: "Jot deleted.", status: :see_other
  end

  # Turns the jot into a task and opens it, so notes, dates and the rest can be filled in.
  def convert
    jot = Jot.find(params[:id])
    attrs = params.fetch(:task, {}).permit(:title, :due_date, :priority, :project_id).to_h.reject { |_, v| v.blank? }
    task, = jot.to_task!(attrs)
    if params[:stay].present?
      redirect_back fallback_location: jots_path, notice: "Made a task: “#{task.title}”."
    else
      redirect_to edit_task_path(task), notice: "Made a task from your jot."
    end
  end

  private

  def jot_params
    params.require(:jot).permit(:body, :pinned)
  end
end
