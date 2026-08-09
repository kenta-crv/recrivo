# frozen_string_literal: true

module InterviewFollowUp
  class CancelRemainingService
    def self.call(interview:, kind: nil)
      scope = interview.follow_up_deliveries.where(status: %w[scheduled failed])
      scope = scope.where(kind: kind) if kind.present?
      scope.find_each(&:cancel!)
    end
  end
end
