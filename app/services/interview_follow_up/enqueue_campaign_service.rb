# frozen_string_literal: true

module InterviewFollowUp
  class EnqueueCampaignService
    def self.call(interview:, kind:, base_time: Time.current, force: false)
      new(interview: interview, kind: kind, base_time: base_time, force: force).call
    end

    def initialize(interview:, kind:, base_time:, force: false)
      @interview = interview
      @kind = kind.to_s
      @base_time = base_time
      @force = force
    end

    def call
      return unless eligible?

      situation.ensure_follow_up_templates!

      ActiveRecord::Base.transaction do
        interview = Interview.lock.find(@interview.id)
        return if interview.follow_up_deliveries.active.where(kind: @kind).exists?

        interview.ensure_follow_up_unsubscribe_token!
        enabled_templates.each { |template| create_delivery!(interview, template) }
      end

      send_immediate_deliveries!
    end

    private

    def situation
      @interview.situation
    end

    def client
      situation.client
    end

    def eligible?
      return false if @interview.preview?
      return false unless follow_up_allowed?
      return false if @interview.user&.email.blank?
      return false if @interview.user.guest?
      return false if @interview.follow_up_unsubscribed?

      true
    end

    def follow_up_allowed?
      @force || client&.follow_up_automation_enabled?
    end

    def enabled_templates
      situation.interview_follow_up_templates.enabled.for_kind(@kind).ordered
    end

    def create_delivery!(interview, template)
      interview.follow_up_deliveries.create!(
        interview_follow_up_template: template,
        sequence: template.sequence,
        kind: template.kind,
        subject: template.subject,
        body: template.body,
        scheduled_at: @base_time + template.delay_days.days,
        status: "scheduled"
      )
    end

    def send_immediate_deliveries!
      @interview.follow_up_deliveries
                .where(kind: @kind, status: %w[scheduled failed])
                .where("scheduled_at <= ?", Time.current)
                .includes(:interview_follow_up_template)
                .find_each do |delivery|
        next if delivery.interview_follow_up_template.delay_days.to_i.positive?

        SendDeliveryService.call(delivery)
      rescue StandardError => e
        Rails.logger.error("[InterviewFollowUp] immediate send failed delivery_id=#{delivery.id}: #{e.class}: #{e.message}")
      end
    end
  end
end
