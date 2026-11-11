module Api
  module V1
    class EventsController < BaseController
      # GET /api/v1/events?start=2026-11-01&end=2026-12-01&calendar_id=&kind=event|time_block&task_id=&q=
      # Repeating events are expanded: one entry per occurrence, each with `occurrence`.
      def index
        from, to = TimeInput.range(params[:start], params[:end])
        render json: CalendarQuery.events(from, to, calendar_id: params[:calendar_id].presence,
                                          kind: params[:kind], task_id: params[:task_id].presence, query: params[:q])
      end

      def show
        render json: Event.find(params[:id]).as_api_json
      end

      def create
        render json: EventWriter.create!(body_params.except("occurrence")).as_api_json, status: :created
      end

      # PATCH /api/v1/events/:id[?occurrence=<start>] — with occurrence, only that occurrence changes.
      def update
        event = Event.find(params[:id])
        attrs = body_params.except("occurrence", "id")
        result = params[:occurrence].present? ? EventWriter.update_occurrence!(event, params[:occurrence], attrs) : EventWriter.update!(event, attrs)
        render json: result.as_api_json
      end

      # DELETE /api/v1/events/:id[?occurrence=<start>] — with occurrence, only that one is skipped.
      def destroy
        event = Event.find(params[:id])
        params[:occurrence].present? ? EventWriter.delete_occurrence!(event, params[:occurrence]) : event.destroy!
        head :no_content
      end
    end
  end
end
