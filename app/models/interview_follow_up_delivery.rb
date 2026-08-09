# frozen_string_literal: true

class InterviewFollowUpDelivery < ApplicationRecord
  belongs_to :interview
  belongs_to :interview_follow_up_template

  STATUSES = %w[scheduled sent opened cancelled failed].freeze

  validates :sequence, :kind, :status, :scheduled_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_create :ensure_tokens

  scope :pending_send, -> {
    where(status: %w[scheduled failed]).where("scheduled_at <= ?", Time.current)
  }
  scope :active, -> { where.not(status: "cancelled") }

  def mark_sent!
    update!(status: "sent", sent_at: Time.current, error_message: nil)
  end

  def mark_opened!
    attrs = { opened_at: Time.current }
    attrs[:status] = "opened" if status == "sent"
    update!(attrs)
  end

  def mark_next_step_clicked!
    update!(next_step_clicked_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled")
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s.truncate(500))
  end

  private

  def ensure_tokens
    self.tracking_token ||= SecureRandom.urlsafe_base64(24)
    self.next_step_token ||= SecureRandom.urlsafe_base64(24)
  end
end
