module Api
  module V1
    class AgendaController < BaseController
      # GET /api/v1/agenda?date=2026-11-12&days=1
      def show
        render json: Agenda.build(TimeInput.parse_date(params[:date]), params.fetch(:days, 1))
      end

      # GET /api/v1/free_time?date=&day_start=08:00&day_end=18:00&min_minutes=30
      def free_time
        day = TimeInput.parse_date(params[:date]) || Time.zone.today
        render json: CalendarQuery.free_slots(day, day_start: params[:day_start], day_end: params[:day_end],
                                              min_minutes: params.fetch(:min_minutes, 30).to_i.clamp(5, 1440))
      end
    end
  end
end
