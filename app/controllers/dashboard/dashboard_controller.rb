class Dashboard::DashboardController < Dashboard::BaseController
  def index
    if admin_signed_in?
      situations_scope_rel = Situation.all
      results_scope = InterviewResult.includes(interview: [:user, :situation])
                                    .joins(:interview).where(interviews: { preview: false })
      interviews_scope = Interview.real
      @display_name = t("recrivo.dashboard.home.admin_name")
      situation_ids = situations_scope_rel.pluck(:id)
    else
      situations_scope_rel = current_client.situations
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
    @recent_candidates = interviews_scope.includes(:user, :situation, :interview_result).order(updated_at: :desc).limit(5)

    @analytics = InterviewEngine::AnalyticsSummaryService.call(situation_ids: situation_ids)
    @average_score = @analytics[:average_score]
    @abandon_rate = if @analytics[:sessions_started].to_i.zero?
                      nil
                    else
                      ((@analytics[:sessions_abandoned].to_f / @analytics[:sessions_started]) * 100).round(1)
                    end
    @abandoned_count = @analytics[:sessions_abandoned]
    @decided_interview_count = @analytics[:sessions_completed]
    @interviews_this_month = interviews_scope.where(created_at: Time.current.all_month).count

    experience = CandidateExperienceScore.for_situations(
      situations_scope_rel.active.with_attached_recruitment_material.includes(:situation_faqs, :questions)
    )
    @experience_score = experience[:average_score]
    @experience_has_gaps = experience[:items].any? { |item| item.gaps.any? }

    unless admin_signed_in?
      @monthly_limit = current_client.monthly_interview_limit
    end

    render "dashboard/index"
  end
end
