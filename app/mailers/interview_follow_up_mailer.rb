# frozen_string_literal: true

class InterviewFollowUpMailer < ApplicationMailer
  def follow_up(delivery:, subject:, body:, html_body:)
    @body = body
    @html_body = html_body
    interview = delivery.interview
    client = interview.situation.client

    mail(
      to: interview.user.email,
      subject: subject,
      reply_to: client&.email,
      from: "info@j-work.jp"
    ) do |format|
      format.text { render plain: body }
      format.html { render html: html_body }
    end
  end
end
