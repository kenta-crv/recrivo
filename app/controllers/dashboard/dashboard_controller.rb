class Dashboard::DashboardController < Dashboard::BaseController
  def index
    if admin_signed_in?
      situations_scope = Situation.includes(:client, :questions)
      results_scope = InterviewResult.includes(interview: [:user, :situation])
      interviews_scope = Interview.all
      @display_name = "管理者"
    else
      situations_scope = current_client.situations.includes(:questions)
      results_scope = InterviewResult
        .joins(interview: :situation)
        .where(situations: { client_id: current_client.id })
        .includes(interview: [:user, :situation])
      interviews_scope = Interview.joins(:situation).where(situations: { client_id: current_client.id })
      @display_name = current_client.name.presence || current_client.email
    end

    @situations_count = situations_scope.count
    @active_situations_count = situations_scope.active.count
    @results_count = results_scope.count
    @recent_results = results_scope.order(created_at: :desc).limit(8)
    @recent_situations = situations_scope.order(updated_at: :desc).limit(5)

    scores = results_scope.pluck(:results_data).filter_map do |raw|
      data = raw.is_a?(String) ? (JSON.parse(raw) rescue nil) : raw
      data = JSON.parse(data) rescue data if data.is_a?(String)
      next unless data.is_a?(Hash)

      score = data['average_score'] || data[:average_score]
      score.nil? ? nil : score.to_f
    end
    @average_score = scores.empty? ? nil : (scores.sum / scores.size).round(1)

    decided_count = interviews_scope.where(status: [:completed, :failed, :abandoned]).count
    abandoned_count = interviews_scope.where(status: :abandoned).count
    @abandon_rate = decided_count.zero? ? nil : ((abandoned_count.to_f / decided_count) * 100).round(1)
    @abandoned_count = abandoned_count
    @decided_interview_count = decided_count

    unless admin_signed_in?
      @interviews_this_month = current_client.interviews_this_month_count
      @monthly_limit = current_client.monthly_interview_limit
    end

    render "dashboard/index"
  end
end
