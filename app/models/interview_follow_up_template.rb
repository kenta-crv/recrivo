# frozen_string_literal: true

class InterviewFollowUpTemplate < ApplicationRecord
  belongs_to :situation

  KINDS = %w[incomplete completed].freeze

  validates :sequence, :kind, :subject, :body, :delay_days, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :sequence, uniqueness: { scope: [:situation_id, :kind] }
  validates :delay_days, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 90 }

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:sequence) }
  scope :for_kind, ->(kind) { where(kind: kind) }
end
