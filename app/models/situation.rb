class Situation < ApplicationRecord
  belongs_to :client
  has_many :questions, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews

  validates :title, presence: true
  validates :industry, :job_title, presence: true
  validates :invite_token, presence: true, uniqueness: true
  validates :session_timeout_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 180 }
  validates :max_resume_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :passing_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :min_required_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :max_consecutive_fails, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :reject_notify_method, inclusion: { in: %w[in_app email none] }
  validates :judgment_mode, inclusion: { in: %w[automatic manual] }
  validates :candidate_result_visibility, inclusion: { in: %w[immediate hidden] }
  validate :at_least_one_answer_mode_enabled

  enum language: { en: 'en', ja: 'ja' }

  before_validation :ensure_invite_token, on: :create

  scope :active, -> { where(archived: false) }

  def allow_resume?
    allow_resume
  end

  def allow_text_answer?
    allow_text_answer
  end

  def allow_voice_answer?
    allow_voice_answer
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

  def at_least_one_answer_mode_enabled
    return if allow_text_answer? || allow_voice_answer?

    errors.add(:base, 'テキスト回答または音声回答のどちらか一方は有効にしてください')
  end
end
