class SessionsController < ApplicationController
  skip_before_action :require_login
  rate_limit to: 8, within: 15.minutes, only: :create,
             with: -> { redirect_to login_path, alert: "Too many attempts. Try again in a few minutes." }
  layout "auth"

  def new
    redirect_to root_path if signed_in?
  end

  def create
    if Organizer.admin_password.blank?
      redirect_to login_path, alert: "Set ADMIN_PASSWORD on the server first."
    elsif OwnerAuthentication.password_matches?(params[:password])
      sign_in!
      redirect_to root_path
    else
      redirect_to login_path, alert: "Wrong password."
    end
  end

  def destroy
    sign_out!
    redirect_to login_path
  end
end
