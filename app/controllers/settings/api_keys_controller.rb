module Settings
  class ApiKeysController < ApplicationController
    def create
      _key, raw = ApiKey.generate!(params[:name].to_s.strip.presence || "API key")
      flash[:new_api_key] = raw
      redirect_to settings_path(anchor: "api-keys")
    end

    def destroy
      ApiKey.find(params[:id]).revoke!
      redirect_to settings_path(anchor: "api-keys"), notice: "Key revoked.", status: :see_other
    end
  end
end
