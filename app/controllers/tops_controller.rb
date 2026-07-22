class TopsController < ApplicationController
  layout "lp"

  before_action :set_lp_nav, only: :index

  def index
  end

  # situation_id 直打ちは受験入口にしない（招待リンクのみ）
  def interview
    current_client&.check_and_upgrade_expired_trial
    flash.now[:alert] = "面接は企業から送られた招待リンクからご参加ください。"
    @invite_required = true
    render :interview_gate, layout: "application"
  end

  def interview_invite
    current_client&.check_and_upgrade_expired_trial
    @situation = Situation.active.find_by!(invite_token: params[:token])
    @invite_token = @situation.invite_token
    @hide_site_chrome = true
    render :interview, layout: "application"
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "招待リンクが無効か、シナリオが公開されていません。"
  end

  private

  def set_lp_nav
    @lp_page = "index"
  end
end
