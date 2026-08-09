# frozen_string_literal: true

class InterviewEvent < ApplicationRecord
  belongs_to :interview, optional: true
  belongs_to :situation

  EVENT_TYPES = %w[
    invite_open
    registration_submit
    interview_start
    question_view
    answer_submit
    interview_complete
    interview_abandon
    satisfaction_submit
    materials_download
    faq_view
    preview_start
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

  scope :real, -> { where(preview: false) }
  scope :for_situations, ->(ids) { where(situation_id: ids) }

  def self.track!(situation:, event_type:, interview: nil, question_id: nil, session_key: nil, metadata: {}, preview: false)
    create!(
      situation: situation,
      interview: interview,
      question_id: question_id,
      event_type: event_type,
      session_key: session_key,
      metadata: metadata || {},
      preview: preview
    )
  rescue StandardError => e
    Rails.logger.warn("[InterviewEvent] track failed: #{e.class}: #{e.message}")
    nil
  end
end
