class Dashboard::BaseController < ApplicationController
  layout "dashboard"
  before_action :authenticate_dashboard_user!

  private

  def authenticate_dashboard_user!
    return if client_signed_in? || admin_signed_in?

    redirect_to new_client_session_path, alert: "ログインが必要です。"
  end

  def authenticate_client_only!
    return if client_signed_in?

    redirect_to dashboard_root_path, alert: "企業アカウントでのログインが必要です。"
  end
end
