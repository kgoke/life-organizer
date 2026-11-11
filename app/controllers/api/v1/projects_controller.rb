module Api
  module V1
    class ProjectsController < BaseController
      def index
        scope = bool_param(:include_archived, false) ? Project.all : Project.active
        render json: scope.ordered.map(&:as_api_json)
      end

      def create
        render json: Project.create!(body_params("name", "color", "position")).as_api_json, status: :created
      end

      def update
        project = Project.find(params[:id])
        project.update!(body_params("name", "color", "position", "archived"))
        render json: project.as_api_json
      end

      def destroy
        Project.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end
