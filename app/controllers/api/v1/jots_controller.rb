module Api
  module V1
    class JotsController < BaseController
      # GET /api/v1/jots?q=
      def index
        scope = Jot.ordered
        scope = scope.where("body LIKE ?", "%#{Jot.sanitize_sql_like(params[:q].strip)}%") if params[:q].present?
        render json: scope.limit(500).map(&:as_api_json)
      end

      def show
        render json: Jot.find(params[:id]).as_api_json
      end

      def create
        render json: Jot.create!(body_params("body", "pinned")).as_api_json, status: :created
      end

      def update
        jot = Jot.find(params[:id])
        jot.update!(body_params("body", "pinned"))
        render json: jot.as_api_json
      end

      def destroy
        Jot.find(params[:id]).destroy!
        head :no_content
      end

      # POST /api/v1/jots/:id/convert  {title?, notes?, due_date?, ..., schedule_start?, duration_minutes?}
      # Turns the jot into a task, optionally time-blocked, and removes the jot.
      def convert
        jot = Jot.find(params[:id])
        attrs = body_params(*TaskWriter::FIELDS.map(&:to_s))
        task, block = jot.to_task!(attrs, schedule_start: body_params["schedule_start"], duration_minutes: body_params["duration_minutes"])
        render json: { task: task.reload.as_api_json, time_block: block&.as_api_json }, status: :created
      end
    end
  end
end
