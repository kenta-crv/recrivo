class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  def full_name
    "#{company} #{name}".strip
  end

  def guest?
    email.to_s.end_with?('@interview.local')
  end
end
