module Settings
  class ConnectedAppsController < ApplicationController
    def destroy
      client = OauthClient.find(params[:id])
      client.oauth_tokens.live.find_each(&:revoke!)
      redirect_to settings_path(anchor: "connections"), notice: "#{client.name} disconnected.", status: :see_other
    end
  end
end
