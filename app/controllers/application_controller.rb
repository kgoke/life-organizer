class ApplicationController < ActionController::Base
  include OwnerAuthentication

  before_action :require_login

  rescue_from Organizer::Invalid, ActiveRecord::RecordInvalid do |e|
    message = e.respond_to?(:record) && e.record ? e.record.errors.full_messages.to_sentence : e.message
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.any { redirect_back fallback_location: root_path, alert: message }
    end
  end

  private

  def require_login
    return if signed_in?
    respond_to do |format|
      format.json { render json: { error: "Not signed in" }, status: :unauthorized }
      format.any { redirect_to login_path }
    end
  end
end
