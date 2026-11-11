class FeedsController < ActionController::Base
  def show
    unless ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, AppSetting.feed_token)
      return head :not_found
    end
    include_tasks = params[:tasks] != "false"
    response.headers["Cache-Control"] = "no-store"
    send_data IcsFeed.build(include_tasks: include_tasks), type: "text/calendar; charset=utf-8",
              disposition: "inline", filename: "life-organizer.ics"
  end
end
