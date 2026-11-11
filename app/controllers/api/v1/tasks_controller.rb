module Api
  module V1
    class TasksController < BaseController
      # GET /api/v1/tasks?status=open|all|todo|in_progress|done|cancelled&project_id=&tag=&due_on=&due_before=&due_after=&q=&parent_id=&unscheduled=true
      def index
        render json: TaskQuery.call(params).map { |t| t.as_api_json }
      end

      def show
        render json: Task.find(params[:id]).as_api_json
      end

      def create
        task, = TaskWriter.create!(body_params)
        render json: task.as_api_json, status: :created
      end

      def update
        task, nxt = TaskWriter.update!(Task.find(params[:id]), body_params)
        render json: task.as_api_json.merge(next_occurrence: nxt&.as_api_json)
      end

      def destroy
        Task.find(params[:id]).destroy!
        head :no_content
      end

      def complete
        task = Task.find(params[:id])
        nxt = task.complete!
        render json: { task: task.reload.as_api_json, next_occurrence: nxt&.as_api_json }
      end

      def reopen
        task = Task.find(params[:id])
        task.reopen!
        render json: task.as_api_json
      end

      # POST /api/v1/tasks/:id/schedule {start, end?, duration_minutes?, calendar?}
      def schedule
        b = body_params
        block = CalendarQuery.schedule_task!(Task.find(params[:id]), start: b["start"], end_time: b["end"],
                                             duration_minutes: b["duration_minutes"], calendar: b["calendar_id"] || b["calendar"])
        render json: block.as_api_json, status: :created
      end
    end
  end
end
