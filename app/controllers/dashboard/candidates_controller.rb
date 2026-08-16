# frozen_string_literal: true

class Dashboard::CandidatesController < Dashboard::BaseController
  before_action :set_interview, only: [:show, :update_ops_status]

  def index
    @interviews = interviews_scope
                    .includes(:user, :situation, :interview_result)
                    .order(updated_at: :desc)
                    .limit(200)
    @ops_filter = params[:ops_status].presence
    @interviews = @interviews.where(ops_status: @ops_filter) if @ops_filter.present?
    @situation_filter = params[:situation_id].presence
    @interviews = @interviews.where(situation_id: @situation_filter) if @situation_filter.present?
    @situations = situations_scope.order(:title)
  end

  def show
    @events = @interview.interview_events.order(created_at: :desc).limit(50)
    @deliveries = @interview.follow_up_deliveries.order(:sequence)
    @result = @interview.interview_result
  end

  def update_ops_status
    status = params[:ops_status].to_s
    unless Interview::OPS_STATUSES.include?(status)
      return redirect_to dashboard_candidate_path(@interview), alert: t("recrivo.dashboard.flash.invalid_ops")
    end

    @interview.update!(ops_status: status)
    redirect_to dashboard_candidate_path(@interview), notice: t("recrivo.dashboard.flash.ops_updated")
  end

  private

  def interviews_scope
    scope = Interview.real.joins(:situation)
    if client_signed_in?
      scope.where(situations: { client_id: current_client.id })
    elsif admin_signed_in?
      scope
    else
      Interview.none
    end
  end

  def set_interview
    @interview = interviews_scope.find(params[:id])
  end
end
