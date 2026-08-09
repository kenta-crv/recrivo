# frozen_string_literal: true

class InterviewNotificationMailer < ApplicationMailer
  default from: "info@j-work.jp"

  # 候補者への自動不合格通知
  def candidate_rejection(interview:, reason:)
    @interview = interview
    @user = interview.user
    @situation = interview.situation
    @client = @situation.client
    @reason = reason

    mail(
      to: @user.email,
      subject: "【選考結果】#{@client.company.presence || @client.name}「#{@situation.title}」",
      reply_to: @client.email
    )
  end

  # 企業への面接完了通知
  def client_interview_completed(interview:)
    @interview = interview
    @user = interview.user
    @situation = interview.situation
    @client = @situation.client
    @result = interview.interview_result

    mail(
      to: @client.email,
      subject: "【面接完了】#{@user.name.presence || @user.email} — #{@situation.title}"
    )
  end
end
