# frozen_string_literal: true

module InterviewFollowUp
  class SendDueDeliveriesService
    def self.call
      InterviewFollowUpDelivery.pending_send
                              .includes(:interview, :interview_follow_up_template)
                              .find_each do |delivery|
        next if delivery.interview.preview?
        next if delivery.interview.follow_up_unsubscribed?

        SendDeliveryService.call(delivery)
      rescue StandardError => e
        Rails.logger.error("[InterviewFollowUp] send_due failed delivery_id=#{delivery.id}: #{e.class}: #{e.message}")
      end
    end
  end
end
