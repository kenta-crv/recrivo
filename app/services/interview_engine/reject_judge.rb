# app/services/interview_engine/reject_judge.rb
module InterviewEngine
  class RejectJudge
    class RejectionError < StandardError; end

    RejectDecision = Struct.new(:rejected, :reason, :details, keyword_init: true) do
      def rejected?
        rejected
      end
    end

    def initialize(interview)
      @interview = interview
      @situation = interview.situation
    end

    # 個別回答評価後のリアルタイム判定
    # ResponseEvaluator から各回答評価後に呼ばれる
    def judge_after_response(interview_response)
      return not_rejected unless @situation.auto_reject_enabled?

      # 必須質問の不合格で即リジェクト
      if @situation.reject_on_required_fail? && interview_response.question.required?
        score = interview_response.score.to_f
        if score < @situation.min_required_score
          return reject(
            "required_question_failed",
            "必須質問「#{interview_response.question.question_text.truncate(30)}」のスコアが基準未達（#{score.round}点 / #{@situation.min_required_score}点）",
            question_id: interview_response.question_id,
            score: score,
            threshold: @situation.min_required_score
          )
        end
      end

      # 連続不合格チェック
      if @situation.max_consecutive_fails > 0
        consecutive = count_consecutive_fails
        if consecutive >= @situation.max_consecutive_fails
          return reject(
            "consecutive_fails",
            "#{consecutive}問連続で不合格（上限: #{@situation.max_consecutive_fails}問）",
            consecutive_count: consecutive,
            max_allowed: @situation.max_consecutive_fails
          )
        end
      end

      not_rejected
    end

    # 面接完了時の最終判定
    # SessionManager#complete_interview から呼ばれる
    # ※途中で記録した必須未達も、ここで改めて最終不合格理由にする
    def judge_on_completion(responses)
      return not_rejected unless @situation.auto_reject_enabled?

      if @situation.reject_on_required_fail?
        responses.each do |response|
          next unless response.evaluated?

          question = response.question
          next unless question&.required?

          score = response.score.to_f
          if score < @situation.min_required_score
            return reject(
              "required_question_failed",
              "必須質問「#{question.question_text.truncate(30)}」のスコアが基準未達（#{score.round}点 / #{@situation.min_required_score}点）",
              question_id: question.id,
              score: score,
              threshold: @situation.min_required_score
            )
          end
        end
      end

      scores = responses.map(&:score).compact
      return not_rejected if scores.empty?

      average_score = (scores.sum.to_f / scores.count).round(2)

      if average_score < @situation.passing_score
        return reject(
          "below_passing_score",
          "平均スコアが合格基準未達（#{average_score}点 / #{@situation.passing_score}点）",
          average_score: average_score,
          passing_score: @situation.passing_score,
          total_responses: scores.count
        )
      end

      not_rejected
    end

    # 面接にリジェクト結果を適用（悲観的ロック + トランザクション）
    # 通知は行わない。呼び出し元で通知を実行すること。
    #
    # 回答直後に fail! すると next_question が 400 になり、
    # 「回答が消えて次の音声が再生されない」状態になるため、
    # 途中では理由だけ記録し in_progress のまま続行する。
    # 不合格の確定は SessionManager#complete_interview 側で行う。
    def apply_rejection!(decision)
      return unless decision.rejected?

      @interview.with_lock do
        unless @interview.in_progress?
          Rails.logger.info("RejectJudge: Interview ##{@interview.id} is no longer in_progress (#{@interview.status}), skipping rejection")
          return
        end

        # 既に早期リジェクト理由がある場合は上書きしない
        return if @interview.rejection_reason.present?

        @interview.update!(
          rejection_reason: decision.reason,
          rejected_at: Time.current
        )
      end
    end

    private

    def reject(reason_code, reason_message, **details)
      RejectDecision.new(
        rejected: true,
        reason: reason_message,
        details: { reason_code: reason_code, **details, judged_at: Time.current.iso8601 }
      )
    end

    def not_rejected
      RejectDecision.new(rejected: false, reason: nil, details: nil)
    end

    def count_consecutive_fails
      consecutive = 0
      @interview.interview_responses
                .where(evaluation_status: :completed)
                .order(created_at: :desc)
                .each do |r|
        if r.passed_evaluation?
          break
        else
          consecutive += 1
        end
      end

      consecutive
    end
  end
end
