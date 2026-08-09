class Dashboard::DashboardController < Dashboard::BaseController
  def index
    if admin_signed_in?
      situations_scope_rel = Situation.includes(:client, :questions)
      results_scope = InterviewResult.includes(interview: [:user, :situation])
                                    .joins(:interview).where(interviews: { preview: false })
      interviews_scope = Interview.real
      @display_name = "管理者"
      situation_ids = situations_scope_rel.pluck(:id)
    else
      situations_scope_rel = current_client.situations.includes(:questions)
      results_scope = InterviewResult
        .joins(interview: :situation)
        .where(situations: { client_id: current_client.id }, interviews: { preview: false })
        .includes(interview: [:user, :situation])
      interviews_scope = Interview.real.joins(:situation).where(situations: { client_id: current_client.id })
      @display_name = current_client.name.presence || current_client.email
      situation_ids = situations_scope_rel.pluck(:id)
      @unread_notifications = current_client.notifications.unread.count
    end

    @situations_count = situations_scope_rel.count
    @active_situations_count = situations_scope_rel.active.count
    @results_count = results_scope.count
    @recent_results = results_scope.order(created_at: :desc).limit(8)
    @recent_situations = situations_scope_rel.order(updated_at: :desc).limit(5)
    @recent_candidates = interviews_scope.includes(:user, :situation).order(updated_at: :desc).limit(8)

    @analytics = InterviewEngine::AnalyticsSummaryService.call(situation_ids: situation_ids)
    @average_score = @analytics[:average_score]
    @abandon_rate = if @analytics[:sessions_started].to_i.zero?
                      nil
                    else
                      ((@analytics[:sessions_abandoned].to_f / @analytics[:sessions_started]) * 100).round(1)
                    end
    @abandoned_count = @analytics[:sessions_abandoned]
    @decided_interview_count = @analytics[:sessions_completed]

    unless admin_signed_in?
      @interviews_this_month = current_client.interviews_this_month_count
      @monthly_limit = current_client.monthly_interview_limit
    end

    render "dashboard/index"
  end
end
