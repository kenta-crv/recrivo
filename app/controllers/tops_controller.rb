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
    @preview_mode = preview_mode_for?(@situation)
    @hide_site_chrome = true

    unless @preview_mode
      @situation.increment_page_views!
      InterviewEvent.track!(
        situation: @situation,
        event_type: "invite_open",
        session_key: request.session.id.to_s,
        metadata: { referer: request.referer.to_s.truncate(200) }
      )
    end

    render :interview, layout: "application"
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "招待リンクが無効か、シナリオが公開されていません。"
  end

  private

  def preview_mode_for?(situation)
    return false unless ActiveModel::Type::Boolean.new.cast(params[:preview])
    return true if acting_as_admin?
    return true if client_signed_in? && situation.client_id == current_client.id

    false
  end

  def set_lp_nav
    @lp_page = "index"
  end
end
