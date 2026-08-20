class Situation < ApplicationRecord
  include SituationCandidateRegistration
  include SituationFollowUpTemplateDefaults

  belongs_to :client
  has_many :questions, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews
  has_many :interview_events, dependent: :destroy
  has_many :situation_faqs, dependent: :destroy
  has_many :interview_follow_up_templates, dependent: :destroy
  has_one_attached :recruitment_material

  validates :title, presence: true
  validates :industry, :job_title, presence: true
  validates :invite_token, presence: true, uniqueness: true
  validates :session_timeout_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 180 }
  validates :max_resume_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :passing_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :min_required_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :max_consecutive_fails, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :reject_notify_method, inclusion: { in: %w[in_app email none] }
  validates :judgment_mode, presence: true, inclusion: { in: %w[automatic manual] }
  validates :candidate_result_visibility, presence: true, inclusion: { in: %w[immediate hidden] }
  validate :at_least_one_answer_mode_enabled

  enum language: { en: 'en', ja: 'ja' }

  before_validation :ensure_invite_token, on: :create
  after_create :ensure_follow_up_templates!
  after_create :increment_client_situation_counter

  scope :active, -> { where(archived: false) }

  def skip_candidate_registration?
    skip_candidate_registration
  end

  def enable_satisfaction_survey?
    enable_satisfaction_survey
  end

  def increment_page_views!
    increment!(:page_views_count)
  end

  def allow_resume?
    allow_resume
  end

  def allow_text_answer?
    allow_text_answer
  end

  def allow_voice_answer?
    allow_voice_answer
  end

  def answer_mode
    if allow_text_answer && !allow_voice_answer
      "text"
    elsif allow_voice_answer && !allow_text_answer
      "voice"
    else
      "both"
    end
  end

  def answer_mode=(value)
    case value.to_s
    when "text"
      self.allow_text_answer = true
      self.allow_voice_answer = false
    when "both"
      self.allow_text_answer = true
      self.allow_voice_answer = true
    else
      self.allow_text_answer = false
      self.allow_voice_answer = true
    end
  end

  def record_camera?
    record_camera
  end

  def auto_reject_enabled?
    auto_reject_enabled
  end

  def reject_on_required_fail?
    reject_on_required_fail
  end

  def automatic_judgment?
    judgment_mode.to_s != 'manual'
  end

  def manual_judgment?
    judgment_mode.to_s == 'manual'
  end

  def hide_result_from_candidate?
    candidate_result_visibility.to_s == 'hidden'
  end

  def regenerate_invite_token!
    update!(invite_token: self.class.generate_unique_invite_token)
  end

  def job_info_present?
    job_summary.present? || employment_type.present? || location.present? ||
      salary_text.present? || requirements_text.present? || selection_flow.present?
  end

  # 候補者向け求人基本情報（面接中=要約、完了後=詳細）
  def candidate_job_info(detail: false)
    return nil unless job_info_present?

    summary = job_summary.to_s
    summary = summary.truncate(280) unless detail

    payload = {
      job_title: job_title,
      employment_type: employment_type,
      location: location,
      salary_text: salary_text,
      job_summary: summary.presence
    }

    if detail
      payload[:requirements_text] = requirements_text
      payload[:selection_flow] = selection_flow
    end

    payload.reject { |_, v| v.blank? }
  end

  def self.generate_unique_invite_token
    loop do
      token = SecureRandom.urlsafe_base64(16)
      break token unless exists?(invite_token: token)
    end
  end

  private

  def ensure_invite_token
    self.invite_token = self.class.generate_unique_invite_token if invite_token.blank?
  end

  def increment_client_situation_counter
    client&.increment!(:total_situations_created)
  end

  def at_least_one_answer_mode_enabled
    return if allow_text_answer? || allow_voice_answer?

    errors.add(:base, 'テキスト回答または音声回答のどちらか一方は有効にしてください')
  end
end
