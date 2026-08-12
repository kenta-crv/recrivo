module DashboardHelper
  def sidebar_account_client
    if defined?(@target_client) && @target_client.present?
      @target_client
    elsif client_signed_in?
      current_client
    end
  end

  def sidebar_dashboard_accessible?
    sidebar_account_client&.dashboard_accessible?
  end

  def sidebar_link_active?(key)
    case key
    when :dashboard
      controller_name == "dashboard" || controller_path == "dashboard/candidate_experiences"
    when :situations
      controller_name == "situations" || controller_name == "questions" || controller_name == "situation_faqs"
    when :interviews, :candidates
      controller_path == "dashboard/candidates" || controller_path == "dashboard/interview_results"
    when :interview_results
      controller_path == "dashboard/interview_results"
    when :notifications
      controller_path == "dashboard/notifications"
    when :subscription
      controller_name == "subscriptions"
    when :account
      controller_name == "accounts"
    when :problems
      controller_name == "problems"
    when :management
      controller_name == "management"
    when :admin_interview_results
      controller_path == "admin/interview_results"
    else
      false
    end
  end

  def sidebar_link_class(key, *extras)
    classes = ["db-v2-sidebar__link", *extras]
    classes << "db-v2-sidebar__link--active" if sidebar_link_active?(key)
    classes.compact.join(" ")
  end

  def sidebar_plan_label
    sidebar_account_client&.current_plan_config&.dig(:name) || "—"
  end

  def sidebar_user_display_name
    client = sidebar_account_client
    client&.name.presence || client&.email.to_s.split("@").first.presence || "User"
  end

  def subscription_path_options
    if admin_signed_in? && defined?(@target_client) && @target_client.present?
      { client_id: @target_client.id }
    else
      {}
    end
  end

  def subscription_can_cancel?(client)
    return false if admin_signed_in?

    client.subscription_cancellable?
  end

  def acting_as_admin?
    admin_signed_in? && !client_signed_in?
  end

  OPS_STATUS_LABELS = {
    "new" => "新規",
    "in_progress" => "進行中",
    "completed" => "完了",
    "pending_review" => "審査待ち",
    "passed" => "合格",
    "failed" => "不合格",
    "abandoned" => "離脱",
    "contacted" => "連絡済み"
  }.freeze

  INTERVIEW_STATUS_LABELS = {
    "not_started" => "未開始",
    "in_progress" => "面接中",
    "completed" => "完了",
    "failed" => "失敗",
    "abandoned" => "離脱"
  }.freeze

  def ops_status_label(status)
    OPS_STATUS_LABELS[status.to_s] || status.to_s
  end

  def ops_status_options
    Interview::OPS_STATUSES.map { |status| [ops_status_label(status), status] }
  end

  def ops_status_badge_class(status)
    modifier =
      case status.to_s
      when "passed", "completed", "contacted" then "live"
      when "failed", "abandoned" then "fail"
      when "in_progress" then "progress"
      else "ready"
      end
    "db-v2-status-badge db-v2-status-badge--#{modifier}"
  end

  def interview_status_label(status)
    INTERVIEW_STATUS_LABELS[status.to_s] || status.to_s
  end

  def final_status_label(status, detailed: false)
    case status.to_s
    when "passed" then "合格"
    when "failed" then "不合格"
    when "pending_review" then (detailed ? "確認待ち（面接官判定）" : "確認待ち")
    else
      status.to_s.presence || "—"
    end
  end

  def final_status_badge_class(status)
    modifier =
      case status.to_s
      when "passed" then "live"
      when "failed" then "fail"
      when "pending_review" then "progress"
      else "ready"
      end
    "db-v2-status-badge db-v2-status-badge--#{modifier}"
  end

  FOLLOW_UP_KIND_LABELS = {
    "incomplete" => "未完了リマインド",
    "completed" => "完了後フォロー"
  }.freeze

  FOLLOW_UP_STATUS_LABELS = {
    "scheduled" => "予約済み",
    "sent" => "送信済み",
    "opened" => "開封済み",
    "failed" => "失敗",
    "cancelled" => "キャンセル",
    "skipped" => "スキップ"
  }.freeze

  def follow_up_kind_label(kind)
    FOLLOW_UP_KIND_LABELS[kind.to_s] || kind.to_s
  end

  def follow_up_status_label(status)
    FOLLOW_UP_STATUS_LABELS[status.to_s] || status.to_s
  end

  def follow_up_template_label(template)
    delay = template.delay_days.to_i
    timing = delay.zero? ? "即時" : "#{delay}日後"
    "#{follow_up_kind_label(template.kind)}（#{timing}）"
  end

  EXPERIENCE_GAP_ANCHORS = {
    "job_info" => "job-info",
    "faqs" => "faqs",
    "materials" => "materials",
    "next_step_url" => "follow-up",
    "published_questions" => "questions"
  }.freeze

  def experience_gap_anchor(key)
    EXPERIENCE_GAP_ANCHORS[key.to_s]
  end

  # ハッシュだけだと Turbo / キャッシュで開閉が外れるため、section クエリも付ける
  def situation_experience_gap_path(gap)
    anchor = experience_gap_anchor(gap.key)
    if anchor.present?
      situation_path(gap.situation_id, section: anchor, anchor: anchor)
    else
      situation_path(gap.situation_id)
    end
  end

  def situation_section_param
    params[:section].to_s.presence
  end

  def situation_section_open?(*ids)
    current = situation_section_param
    return false if current.blank?

    ids.flatten.map(&:to_s).include?(current)
  end
end
