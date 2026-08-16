class Dashboard::BaseController < ApplicationController
  layout "dashboard"
  before_action :authenticate_dashboard_user!
  helper_method :acting_as_admin?

  private

  def authenticate_dashboard_user!
    return if client_signed_in? || admin_signed_in?

    redirect_to helpers.client_sign_in_path_for_locale, alert: t("recrivo.dashboard.flash.login_required")
  end

  def authenticate_client_only!
    return if client_signed_in?

    redirect_to dashboard_root_path, alert: t("recrivo.dashboard.flash.client_login_required")
  end

  # 企業は自社のみ、管理者は全件を扱えるスコープ
  def situations_scope
    if client_signed_in?
      current_client.situations
    elsif admin_signed_in?
      Situation.all
    else
      Situation.none
    end
  end

  def interview_results_scope
    scope = InterviewResult.joins(interview: :situation).where(interviews: { preview: false })
    if client_signed_in?
      scope.where(situations: { client_id: current_client.id })
    elsif admin_signed_in?
      scope
    else
      InterviewResult.none
    end
  end

  def acting_as_admin?
    admin_signed_in? && !client_signed_in?
  end
end
