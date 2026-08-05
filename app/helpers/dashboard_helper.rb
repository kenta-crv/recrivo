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
      controller_name == "dashboard"
    when :situations
      controller_name == "situations" || controller_name == "questions"
    when :interview_results
      controller_path == "dashboard/interview_results"
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
end
