module Settings
  class CalendarsController < ApplicationController
    def create
      Calendar.create!(calendar_params)
      redirect_to settings_path(anchor: "calendars")
    end

    def update
      cal = Calendar.find(params[:id])
      cal.update!(calendar_params)
      cal.make_default! if params.dig(:calendar, :is_default) == "1"
      redirect_to settings_path(anchor: "calendars"), notice: "Saved."
    end

    def destroy
      cal = Calendar.find(params[:id])
      if cal.destroy
        redirect_to settings_path(anchor: "calendars"), notice: "Calendar deleted.", status: :see_other
      else
        redirect_to settings_path(anchor: "calendars"), alert: cal.errors.full_messages.to_sentence, status: :see_other
      end
    end

    private

    def calendar_params = params.require(:calendar).permit(:name, :color, :include_in_feed)
  end
end
