# frozen_string_literal: true

module InterviewEngine
  class AnalyticsSummaryService
    def self.call(situation_ids:)
      new(situation_ids: situation_ids).call
    end

    def initialize(situation_ids:)
      @situation_ids = Array(situation_ids).compact.uniq
    end

    def call
      empty_summary.tap do |summary|
        return summary if @situation_ids.empty?

        summary.merge!(core_counts)
        summary.merge!(funnel_and_rates(summary))
        summary.merge!(follow_up_metrics)
        summary.merge!(satisfaction_metrics)
        summary[:drop_offs] = drop_offs
      end
    end

    private

    def empty_summary
      {
        page_views: 0,
        registered_count: 0,
        sessions_started: 0,
        sessions_completed: 0,
        sessions_failed: 0,
        sessions_abandoned: 0,
        passed_count: 0,
        pending_review_count: 0,
        registration_rate: nil,
        start_rate: nil,
        completion_rate: nil,
        pass_rate: nil,
        average_score: nil,
        average_satisfaction: nil,
        satisfaction_count: 0,
        follow_up_sent: 0,
        follow_up_opened: 0,
        follow_up_clicked: 0,
        funnel_segments: [],
        drop_offs: []
      }
    end

    def interviews
      @interviews ||= Interview.where(situation_id: @situation_ids, preview: false)
    end

    def core_counts
      page_views = Situation.where(id: @situation_ids).sum(:page_views_count)
      registered = interviews.count
      started = interviews.where.not(status: :not_started).count
      completed = interviews.where(status: [:completed, :failed]).count
      failed = interviews.where(status: :failed).count
      abandoned = interviews.where(status: :abandoned).count
      results = InterviewResult.joins(:interview).where(interviews: { situation_id: @situation_ids, preview: false })
      passed = results.where(final_status: :passed).count
      pending = results.where(final_status: :pending_review).count

      scores = results.filter_map do |r|
        data = r.results_data
        data = JSON.parse(data) rescue data if data.is_a?(String)
        next unless data.is_a?(Hash)

        score = data["average_score"] || data[:average_score]
        score.nil? ? nil : score.to_f
      end

      {
        page_views: page_views,
        registered_count: registered,
        sessions_started: started,
        sessions_completed: completed,
        sessions_failed: failed,
        sessions_abandoned: abandoned,
        passed_count: passed,
        pending_review_count: pending,
        average_score: scores.empty? ? nil : (scores.sum / scores.size).round(1)
      }
    end

    def funnel_and_rates(summary)
      views = summary[:page_views].to_i
      registered = summary[:registered_count].to_i
      started = summary[:sessions_started].to_i
      completed = summary[:sessions_completed].to_i
      passed = summary[:passed_count].to_i

      visit_only = [views - registered, 0].max
      lead_only = [registered - started, 0].max
      # started includes completed; started_only = started - completed - abandoned roughly
      abandoned = summary[:sessions_abandoned].to_i
      in_progressish = [started - completed - abandoned, 0].max

      segments = [
        { key: "visit_only", count: visit_only, color: "#94a3b8" },
        { key: "registered_only", count: lead_only, color: "#38bdf8" },
        { key: "started_only", count: in_progressish + abandoned, color: "#f59e0b" },
        { key: "completed", count: completed, color: "#10b981" }
      ]
      total = segments.sum { |s| s[:count] }
      segments.each do |seg|
        seg[:share] = total.zero? ? 0 : ((seg[:count].to_f / total) * 100).round(1)
      end

      {
        registration_rate: rate(registered, views),
        start_rate: rate(started, [registered, 1].max),
        completion_rate: rate(completed, [started, 1].max),
        pass_rate: rate(passed, [completed, 1].max),
        funnel_segments: segments
      }
    end

    def follow_up_metrics
      deliveries = InterviewFollowUpDelivery.joins(:interview)
                                           .where(interviews: { situation_id: @situation_ids, preview: false })
      sent = deliveries.where(status: %w[sent opened]).count
      opened = deliveries.where.not(opened_at: nil).count
      clicked = deliveries.where.not(next_step_clicked_at: nil).count
      {
        follow_up_sent: sent,
        follow_up_opened: opened,
        follow_up_clicked: clicked
      }
    end

    def satisfaction_metrics
      rated = interviews.where.not(satisfaction_rating: nil)
      {
        satisfaction_count: rated.count,
        average_satisfaction: rated.average(:satisfaction_rating)&.round(1)
      }
    end

    def drop_offs
      rows = InterviewEvent.real
                           .where(situation_id: @situation_ids, event_type: "question_view")
                           .group(:question_id)
                           .order(Arel.sql("COUNT(*) DESC"))
                           .limit(5)
                           .count
      rows.map { |qid, count| { question_id: qid, count: count } }
    end

    def rate(num, den)
      return nil if den.to_i <= 0

      ((num.to_f / den) * 100).round(1)
    end
  end
end
