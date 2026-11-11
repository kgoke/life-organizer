module Api
  module V1
    class CalendarsController < BaseController
      def index
        Calendar.default
        render json: Calendar.order(:id).map(&:as_api_json)
      end

      def create
        cal = Calendar.create!(body_params("name", "color", "include_in_feed"))
        cal.make_default! if ActiveModel::Type::Boolean.new.cast(body_params["is_default"])
        render json: cal.as_api_json, status: :created
      end

      def update
        cal = Calendar.find(params[:id])
        cal.update!(body_params("name", "color", "include_in_feed"))
        cal.make_default! if ActiveModel::Type::Boolean.new.cast(body_params["is_default"])
        render json: cal.reload.as_api_json
      end

      def destroy
        Calendar.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end
