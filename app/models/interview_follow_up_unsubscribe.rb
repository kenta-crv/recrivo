# frozen_string_literal: true

class InterviewFollowUpUnsubscribe < ApplicationRecord
  belongs_to :interview

  validates :token, :unsubscribed_at, presence: true
  validates :token, uniqueness: true
end
