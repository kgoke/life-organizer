class SettingsController < ApplicationController
  def show
    @api_keys = ApiKey.active.order(:id)
    @new_key = flash[:new_api_key]
    @connected = OauthClient.joins(:oauth_tokens).merge(OauthToken.live.where("refresh_expires_at > ?", Time.current)).distinct
    @feed_url = "#{Organizer.public_url}/feed/#{AppSetting.feed_token}.ics"
    @mcp_url = "#{Organizer.public_url}/mcp"
    @calendars = Calendar.order(:id)
    @projects = Project.ordered
  end
end
