# frozen_string_literal: true

class Dashboard::NotificationsController < Dashboard::BaseController
  before_action :authenticate_client_only!
  before_action :set_notification, only: [:show, :update]

  def index
    @notifications = current_client.notifications.recent.limit(100)
  end

  def show
    @notification.mark_read!
    if @notification.interview_id.present?
      redirect_to dashboard_candidate_path(@notification.interview_id)
    else
      redirect_to dashboard_notifications_path
    end
  end

  def update
    @notification.mark_read!
    redirect_to dashboard_notifications_path, notice: t("recrivo.dashboard.flash.marked_read")
  end

  def mark_all_read
    current_client.notifications.unread.update_all(read: true, read_at: Time.current)
    redirect_to dashboard_notifications_path, notice: t("recrivo.dashboard.flash.marked_all_read")
  end

  private

  def set_notification
    @notification = current_client.notifications.find(params[:id])
  end
end
