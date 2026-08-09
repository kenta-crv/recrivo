# frozen_string_literal: true

module InterviewFollowUp
  class SendDeliveryService
    def self.call(delivery)
      new(delivery).call
    end

    def initialize(delivery)
      @delivery = delivery
    end

    def call
      interview = @delivery.interview
      return @delivery.cancel! if interview.preview?
      return @delivery.cancel! if interview.follow_up_unsubscribed?
      return if @delivery.status == "cancelled"
      return if @delivery.sent_at.present? && @delivery.status.in?(%w[sent opened])

      renderer = BodyRenderer.new(@delivery)
      InterviewFollowUpMailer.follow_up(
        delivery: @delivery,
        subject: renderer.subject,
        body: renderer.text_body,
        html_body: renderer.html_body
      ).deliver_now

      @delivery.mark_sent!
    rescue StandardError => e
      @delivery.mark_failed!(e.message)
      raise
    end
  end
end
