module PlanLimitable
  extend ActiveSupport::Concern

  def current_plan_config
    Subscription.plan_config(subscription_plan.presence || :trial) || Subscription.plan_config(:trial)
  end

  def situation_limit
    current_plan_config[:situation_limit]
  end

  def monthly_interview_limit
    current_plan_config[:monthly_interview_limit]
  end

  def active_services_count
    situations.active.count
  end

  def service_limit
    situation_limit
  end

  def can_create_service?
    limit = situation_limit
    limit.nil? || active_services_count < limit
  end

  def interviews_this_month_count
    Interview.real
             .joins(:situation)
             .where(situations: { client_id: id })
             .where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
             .count
  end

  def can_start_interview?
    limit = monthly_interview_limit
    limit.nil? || interviews_this_month_count < limit
  end

  def service_limit_message
    "面接シナリオ数の上限（#{situation_limit}件）に達しています。プランをアップグレードしてください。"
  end

  def interview_limit_message
    "今月の面接実施数の上限（#{monthly_interview_limit}件）に達しています。プランをアップグレードしてください。"
  end

  def approaching_limit?(threshold: 0.8)
    [
      [situation_limit, active_services_count],
      [monthly_interview_limit, interviews_this_month_count]
    ].any? do |limit, used|
      limit.to_i.positive? && used.to_f / limit >= threshold
    end
  end
end
