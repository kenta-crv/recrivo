# frozen_string_literal: true

class InterviewDecisionMailer < ApplicationMailer
  def decision_email(interview_result:, decision:, subject:, body:, reply_to: nil)
    @body = body
    html = ERB::Util.html_escape(body.to_s).gsub(/\r\n|\r|\n/, "<br>\n").html_safe
    mail(
      to: interview_result.interview.user.email,
      subject: subject,
      reply_to: reply_to.presence
    ) do |format|
      format.text { render plain: body }
      format.html { render html: html }
    end
  end
end
