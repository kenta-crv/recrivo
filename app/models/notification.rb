# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :client
  belongs_to :interview, optional: true

  CATEGORIES = %w[general interview_completed interview_rejected follow_up].freeze

  validates :title, :category, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_read!
    return if read?

    update!(read: true, read_at: Time.current)
  end
end
