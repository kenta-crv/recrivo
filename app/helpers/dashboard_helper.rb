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

  def localized_plan_name(config)
    return "—" if config.blank?

    I18n.locale.to_s == "en" ? (config[:name_en].presence || config[:name]) : config[:name]
  end

  def sidebar_plan_label
    localized_plan_name(sidebar_account_client&.current_plan_config)
  end

  def candidate_registration_field_label(key)
    I18n.t("recrivo.dashboard.situations.candidate_fields.#{key}", default: key.to_s)
  end

  def sidebar_user_display_name
    client = sidebar_account_client
    client&.name.presence || client&.email.to_s.split("@").first.presence || "User"
  end

  def subscription_path_options
    if acting_as_admin? && defined?(@target_client) && @target_client.present?
      { client_id: @target_client.id }
    else
      {}
    end
  end

  def subscription_can_cancel?(client)
    return false if acting_as_admin?

    client.subscription_cancellable?
  end

  def ops_status_label(status)
    I18n.t("recrivo.dashboard.status.ops.#{status}", default: status.to_s)
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
    I18n.t("recrivo.dashboard.status.interview.#{status}", default: status.to_s)
  end

  def final_status_label(status, detailed: false)
    key = status.to_s
    return "—" if key.blank?

    lookup = if key == "pending_review" && detailed
               "recrivo.dashboard.status.final.pending_review_detailed"
             else
               "recrivo.dashboard.status.final.#{key}"
             end
    I18n.t(lookup, default: key)
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

  def follow_up_kind_label(kind)
    I18n.t("recrivo.dashboard.status.follow_kind.#{kind}", default: kind.to_s)
  end

  def follow_up_status_label(status)
    I18n.t("recrivo.dashboard.status.follow_status.#{status}", default: status.to_s)
  end

  def follow_up_template_label(template)
    delay = template.delay_days.to_i
    timing = if delay.zero?
               I18n.t("recrivo.dashboard.status.follow_immediate")
             else
               I18n.t("recrivo.dashboard.status.follow_days_later", days: delay)
             end
    I18n.t("recrivo.dashboard.status.follow_template", kind: follow_up_kind_label(template.kind), timing: timing)
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
