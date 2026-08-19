class Interview < ApplicationRecord
  belongs_to :user
  belongs_to :situation
  has_many :interview_responses, dependent: :destroy
  has_one :interview_result, dependent: :destroy
  has_many :interview_events, dependent: :nullify
  has_many :follow_up_deliveries, class_name: "InterviewFollowUpDelivery", dependent: :destroy
  has_many :follow_up_unsubscribes, class_name: "InterviewFollowUpUnsubscribe", dependent: :destroy
  has_many :notifications, dependent: :nullify

  OPS_STATUSES = %w[new in_progress completed pending_review passed failed abandoned contacted].freeze

  enum status: {
    not_started: 0,
    in_progress: 1,
    completed: 2,
    failed: 3,
    abandoned: 4
  }

  enum language: {
    en: 'en',
    ja: 'ja'
  }

  validates :user_id, :situation_id, :language, presence: true
  validates :access_token, uniqueness: true, allow_nil: true
  validates :ops_status, inclusion: { in: OPS_STATUSES }
  validates :satisfaction_rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true

  validate :ensure_no_previous_interview, on: :create
  validate :ensure_situation_has_questions, on: :create
  validate :valid_status_transition, if: :status_changed?

  scope :real, -> { where(preview: false) }
  scope :preview_only, -> { where(preview: true) }

  def preview?
    preview
  end

  def follow_up_unsubscribed?
    follow_up_unsubscribed_at.present?
  end

  def ensure_follow_up_unsubscribe_token!
    return follow_up_unsubscribe_token if follow_up_unsubscribe_token.present?

    update!(follow_up_unsubscribe_token: SecureRandom.urlsafe_base64(24))
    follow_up_unsubscribe_token
  end

  def sync_ops_status!
    new_status =
      if rejected? || failed?
        "failed"
      elsif interview_result&.pending_review?
        "pending_review"
      elsif interview_result&.passed?
        "passed"
      elsif completed?
        "completed"
      elsif abandoned?
        "abandoned"
      elsif in_progress?
        "in_progress"
      else
        "new"
      end
    update_column(:ops_status, new_status) if ops_status != new_status && ops_status != "contacted"
  end

  VALID_TRANSITIONS = {
    not_started: [:in_progress],
    in_progress: [:completed, :failed, :abandoned],
    abandoned: [:in_progress],
    completed: [],
    failed: []
  }.freeze

  before_create :generate_access_token

  scope :by_user_and_situation, ->(user, situation) { where(user: user, situation: situation) }
  scope :completed_or_failed, -> { where(status: [:completed, :failed]) }
  scope :by_token, ->(token) { where(access_token: token) }

  def start!
    update!(status: :in_progress, started_at: Time.current, last_activity_at: Time.current)
  end

  def complete!
    update!(status: :completed, ended_at: Time.current)
  end

  def fail!
    update!(status: :failed, ended_at: Time.current)
  end

  def abandon!
    update!(status: :abandoned, ended_at: Time.current)
  end

  def touch_activity!
    update!(last_activity_at: Time.current)
  end

  def timed_out?
    return false unless in_progress? && last_activity_at.present?

    timeout = situation.session_timeout_minutes.minutes
    last_activity_at < timeout.ago
  end

  def resumable?
    return false unless abandoned? || (in_progress? && timed_out?)
    return false unless situation.allow_resume?
    return false if resume_count >= situation.max_resume_count

    true
  end

  def resume!
    raise "Interview cannot be resumed" unless resumable?

    update!(
      status: :in_progress,
      resumed_at: Time.current,
      last_activity_at: Time.current,
      resume_count: resume_count + 1,
      ended_at: nil
    )
  end

  def rejected?
    rejection_reason.present? && rejected_at.present?
  end

  def duration
    return nil unless started_at && ended_at
    (ended_at - started_at).to_i
  end

  def answered_question_count
    interview_responses.count
  end

  def total_questions
    situation.questions.count
  end

  def progress_percentage
    return 0 if total_questions.zero?
    ((answered_question_count.to_f / total_questions) * 100).round(2)
  end

  def remaining_seconds
    return nil unless in_progress? && last_activity_at.present?

    timeout = situation.session_timeout_minutes.minutes
    elapsed = Time.current - last_activity_at
    remaining = timeout - elapsed
    [remaining.to_i, 0].max
  end

  private

  def generate_access_token
    self.access_token = loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless Interview.exists?(access_token: token)
    end
  end

  def ensure_no_previous_interview
    return if preview?

    existing = Interview.by_user_and_situation(user, situation).real.completed_or_failed.exists?
    errors.add(:base, :already_completed) if existing
  end

  def ensure_situation_has_questions
    return if situation.nil?
    errors.add(:situation, :must_have_questions) if situation.questions.none?
  end

  def valid_status_transition
    from = status_was&.to_sym
    to = status&.to_sym
    return if from.nil?
    unless VALID_TRANSITIONS[from]&.include?(to)
      errors.add(:status, :invalid_transition, from: from, to: to)
    end
  end
end
