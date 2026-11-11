module Api
  module V1
    class ConnectionController < BaseController
      def show
        render json: {
          public_url: Organizer.public_url, mcp_url: "#{Organizer.public_url}/mcp", oauth_enabled: Organizer.oauth_enabled?,
          ics_feed_url: "#{Organizer.public_url}/feed/#{AppSetting.feed_token}.ics", time_zone: Time.zone.tzinfo.name,
          day_start: Organizer.day_start, day_end: Organizer.day_end
        }
      end

      def modules
        render json: OrganizerModules.all.map { |m| { name: m.module_name, description: m.description } }
      end
    end
  end
end
