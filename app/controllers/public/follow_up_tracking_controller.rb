# frozen_string_literal: true

class Public::FollowUpTrackingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:open, :click]

  def open
    delivery = InterviewFollowUpDelivery.find_by!(tracking_token: params[:token])
    delivery.mark_opened!
    # 1x1 gif
    send_data Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"),
              type: "image/gif", disposition: "inline"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def click
    delivery = InterviewFollowUpDelivery.find_by!(next_step_token: params[:token])
    delivery.mark_next_step_clicked!
    url = delivery.interview.situation.follow_up_next_step_url.presence || root_path
    redirect_to url
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "リンクが無効です"
  end

  def unsubscribe
    interview = Interview.find_by!(follow_up_unsubscribe_token: params[:token])
    InterviewFollowUp::UnsubscribeService.call(interview: interview, source: "email_link", request: request)
    render plain: "フォローメールの配信を停止しました。", content_type: "text/plain"
  rescue ActiveRecord::RecordNotFound
    render plain: "リンクが無効です。", status: :not_found, content_type: "text/plain"
  end
end
