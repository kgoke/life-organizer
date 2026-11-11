module Settings
  class FeedTokensController < ApplicationController
    def create
      AppSetting.feed_token(regenerate: true)
      redirect_to settings_path(anchor: "feed"), notice: "New feed address made. Update it in your calendar apps."
    end
  end
end
