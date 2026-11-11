module Settings
  class ProjectsController < ApplicationController
    def create
      Project.create!(project_params)
      redirect_back fallback_location: settings_path(anchor: "projects")
    end

    def update
      Project.find(params[:id]).update!(project_params)
      redirect_to settings_path(anchor: "projects"), notice: "Saved."
    end

    def destroy
      Project.find(params[:id]).destroy!
      redirect_to settings_path(anchor: "projects"), notice: "Project deleted. Its tasks were kept.", status: :see_other
    end

    private

    def project_params = params.require(:project).permit(:name, :color, :archived)
  end
end
