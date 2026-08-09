# frozen_string_literal: true

class SituationFaq < ApplicationRecord
  belongs_to :situation

  STATUSES = %w[pending approved skipped].freeze

  validates :question, :answer, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :approved, -> { where(status: "approved") }
  scope :ordered, -> { order(:position, :id) }
end
