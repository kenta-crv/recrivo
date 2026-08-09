# frozen_string_literal: true

class SendInterviewFollowUpsJob < ApplicationJob
  queue_as :default

  def perform
    InterviewFollowUp::SendDueDeliveriesService.call
  end
end
