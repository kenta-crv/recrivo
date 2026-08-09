# frozen_string_literal: true

module InterviewFollowUp
  class UnsubscribeService
    def self.call(interview:, source: "email", request: nil)
      interview.ensure_follow_up_unsubscribe_token!
      interview.update!(follow_up_unsubscribed_at: Time.current) unless interview.follow_up_unsubscribed?

      InterviewFollowUpUnsubscribe.create!(
        interview: interview,
        token: interview.follow_up_unsubscribe_token,
        unsubscribed_at: Time.current,
        source: source,
        ip: request&.remote_ip,
        user_agent: request&.user_agent.to_s.truncate(255)
      )

      CancelRemainingService.call(interview: interview)
    end
  end
end
