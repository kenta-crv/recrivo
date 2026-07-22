# app/services/interview_engine/session_manager.rb
module InterviewEngine
  class SessionManager
    class SessionError < StandardError; end
    class TimeoutError < SessionError; end
    class ResumeError < SessionError; end
    # 1ユーザー1situationにつき1回のみ受験可。完了/失敗済みの再受験を試みた場合に発生。
    class AlreadyCompletedError < SessionError; end

    def initialize(user, situation)
      @user = user
      @situation = situation
    end

    # Start a new interview session
    def start_interview(language: 'en')
      # 既存のin_progress面接があればそれを返す（中断復帰の簡易パス）
      existing_in_progress = Interview.by_user_and_situation(@user, @situation)
                                      .where(status: :in_progress).first
      if existing_in_progress
        existing_in_progress.touch_activity!
        return existing_in_progress
      end

      # 完了/失敗済み面接がある場合は再受験不可（1ユーザー1situation = 1回のみ）
      existing_done = Interview.by_user_and_situation(@user, @situation).completed_or_failed.first
      raise AlreadyCompletedError, "Interview already completed for this situation" if existing_done

      # abandoned面接があれば復帰を試みる
      existing_abandoned = Interview.by_user_and_situation(@user, @situation)
                                    .where(status: :abandoned).first
      if existing_abandoned && existing_abandoned.resumable?
        return resume_interview(existing_abandoned.id)
      end

      interview = Interview.create!(
        user: @user,
        situation: @situation,
        status: :not_started,
        language: language
      )

      interview.start!
      interview
    rescue ActiveRecord::RecordInvalid => e
      raise SessionError, "Failed to start interview: #{e.message}"
    end

    # トークンで面接を開始/復帰（Devise認証不要）
    def self.start_by_token(access_token)
      interview = Interview.by_token(access_token).first
      raise SessionError, "Invalid interview token" unless interview

      manager = new(interview.user, interview.situation)
      manager.handle_token_start(interview)
    end

    def handle_token_start(interview)
      if interview.in_progress?
        if interview.timed_out?
          interview.abandon!
          raise TimeoutError, "Interview session has timed out"
        end
        interview.touch_activity!
        interview
      elsif interview.not_started?
        interview.start!
        interview
      elsif interview.abandoned?
        if interview.resumable?
          resume_interview(interview.id)
        else
          raise ResumeError, "Interview cannot be resumed (max retries exceeded)"
        end
      elsif interview.completed? || interview.failed?
        raise AlreadyCompletedError, "Interview has already ended (#{interview.status})"
      end
    end

    # 面接を再開
    def resume_interview(interview_id)
      interview = Interview.find(interview_id)

      unless interview.resumable?
        raise ResumeError, "Interview cannot be resumed"
      end

      interview.resume!
      interview
    end

    # セッションアクティビティを更新（タイムアウト延長）
    def touch_session(interview_id)
      interview = Interview.find(interview_id)

      if interview.timed_out?
        interview.abandon!
        raise TimeoutError, "Interview session has timed out"
      end

      interview.touch_activity!
      interview
    end

    # タイムアウトチェック（操作前に呼ぶ）
    def check_timeout!(interview_id)
      interview = Interview.find(interview_id)
      return unless interview.in_progress?

      if interview.timed_out?
        interview.abandon!
        raise TimeoutError, "Interview session has timed out"
      end
    end

    # Get current interview state
    def get_interview_state(interview_id)
      interview = Interview.find(interview_id)

      {
        interview_id: interview.id,
        status: interview.status,
        progress: interview.progress_percentage,
        answered_questions: interview.answered_question_count,
        total_questions: interview.total_questions,
        duration_seconds: interview.started_at ? (Time.current - interview.started_at).to_i : 0,
        remaining_seconds: interview.remaining_seconds,
        resume_count: interview.resume_count,
        resumable: interview.resumable?
      }
    end

    # Mark interview as failed (with optional rejection details)
    # 注意: リジェクト経由の場合は RejectJudge#apply_rejection! を使うこと。
    # このメソッドは手動での不合格判定等に使用する。
    def fail_interview(interview_id, reason, rejection_details: nil)
      interview = Interview.find(interview_id)

      interview.with_lock do
        # 既にInterviewResultが存在する場合はそれを返す
        existing_result = interview.interview_result
        return existing_result if existing_result

        interview.fail!

        responses = interview.interview_responses.includes(:question).in_order.to_a
        summary_data = generate_summary(responses, interview.language)
        scores = responses.select(&:evaluated?).map(&:score).compact
        average_score = scores.empty? ? 0 : (scores.sum.to_f / scores.count).round(2)

        result_data = {
          failure_reason: reason,
          completed_at: Time.current,
          total_questions: interview.total_questions,
          answered_questions: responses.size,
          average_score: average_score,
          summary: summary_data[:summary],
          strengths: summary_data[:strengths],
          weaknesses: summary_data[:weaknesses],
          recommendation: summary_data[:recommendation]
        }

        InterviewResult.create!(
          interview: interview,
          final_status: :failed,
          results_data: result_data,
          rejection_details: rejection_details || {}
        )
      end

      notify_rejection(interview, reason) if rejection_details.present?

      true
    end

    # Complete interview and generate results
    def complete_interview(interview_id)
      interview = Interview.find(interview_id)

      # Ensure all responses are evaluated
      pending_responses = interview.interview_responses.where(evaluation_status: :pending)
      raise SessionError, "Cannot complete: #{pending_responses.count} responses still pending evaluation" if pending_responses.any?

      interview.lock!
      interview.complete!

      generate_interview_result(interview)
    end

    # タイムアウトした面接を一括abandon（バッチ処理用）
    # 複数ワーカー同時実行時の二重abandon!を防ぐため with_lock + 状態再確認を行う
    def self.expire_timed_out_sessions!
      Interview.where(status: :in_progress)
               .where.not(last_activity_at: nil)
               .includes(:situation)
               .find_each do |interview|
        next unless interview.timed_out?

        interview.with_lock do
          # ロック取得後に最新状態を再確認（競合下で他ワーカーが既にabandon済みの可能性）
          interview.reload
          next unless interview.in_progress? && interview.timed_out?
          interview.abandon!
          Rails.logger.info("Interview ##{interview.id} expired due to timeout")
        end
      end
    end

    # 既存結果に AI総評が無い場合に生成して保存する（早期リジェクト等で空のまま残ったケース向け）
    def self.ensure_summary!(interview_result, force: false)
      return interview_result if !force && interview_result.summary.present?

      interview = interview_result.interview
      responses = interview.interview_responses.includes(:question).in_order.to_a
      language = interview.language.presence || 'ja'
      manager = new(interview.user, interview.situation)
      summary_data = manager.send(:generate_summary, responses, language)

      interview_result.summary = summary_data[:summary]
      interview_result.strengths = summary_data[:strengths]
      interview_result.weaknesses = summary_data[:weaknesses]
      interview_result.recommendation = summary_data[:recommendation]

      if interview_result.average_score.blank? && responses.any?
        scores = responses.select(&:evaluated?).map(&:score).compact
        interview_result.average_score = scores.empty? ? 0 : (scores.sum.to_f / scores.count).round(2)
        interview_result.answered_questions ||= responses.size
        interview_result.total_questions ||= interview.total_questions
      end

      interview_result.save!
      interview_result
    end

    private

    def generate_interview_result(interview)
      # 既にInterviewResultが存在する場合はそれを返す（重複作成防止）
      # 早期リジェクト等で summary が空のまま残っている場合はここで埋める
      existing_result = interview.interview_result
      if existing_result
        self.class.ensure_summary!(existing_result) if existing_result.summary.blank?
        return existing_result.reload
      end

      # 評価直後の最新スコアを確実に読む（associationキャッシュで旧82点等が残るのを防ぐ）
      interview.interview_responses.reset
      responses = interview.interview_responses.includes(:question).in_order.to_a
      responses.each(&:reload)

      passed_responses = responses.count(&:passed_evaluation?)
      total_responses = responses.size
      scores = responses.select(&:evaluated?).map(&:score).compact

      average_score = scores.empty? ? 0 : (scores.sum.to_f / scores.count).round(2)
      passing_score = interview.situation.passing_score

      # RejectJudge による最終判定
      # 必須質問の基準未達は平均点とは別ルール（設定どおり不合格）
      judge = RejectJudge.new(interview)
      rejection = judge.judge_on_completion(responses)
      early_rejected = interview.rejection_reason.present?
      situation = interview.situation
      failure_reason = if rejection.rejected?
                         rejection.reason
                       elsif early_rejected
                         interview.rejection_reason
                       end

      final_status = if situation.manual_judgment?
                       :pending_review
                     elsif rejection.rejected? || early_rejected
                       :failed
                     elsif average_score >= passing_score
                       :passed
                     else
                       :failed
                     end

      summary_data = generate_summary(responses, interview.language)
      conversation_log = responses.map do |r|
        {
          question: r.question.question_text,
          answer: r.audio_transcript,
          score: r.score
        }
      end

      result_data = {
        total_questions: interview.total_questions,
        answered_questions: total_responses,
        skipped_questions: interview.total_questions - total_responses,
        average_score: average_score,
        passing_score: passing_score,
        passed_count: passed_responses,
        summary: summary_data[:summary],
        strengths: summary_data[:strengths],
        weaknesses: summary_data[:weaknesses],
        recommendation: summary_data[:recommendation],
        conversation_log: conversation_log,
        responses_summary: responses.map { |r|
          {
            question: r.question.question_text,
            score: r.score,
            passed: r.passed_evaluation?
          }
        }
      }

      if failure_reason.present?
        result_data[:failure_reason] = failure_reason
      end

      rejection_details = if rejection.rejected?
                            rejection.details || {}
                          elsif early_rejected
                            { reason_code: 'early_rejection', reason: interview.rejection_reason }
                          else
                            {}
                          end

      if failure_reason.present? && interview.rejection_reason.blank?
        interview.update!(rejection_reason: failure_reason, rejected_at: Time.current)
      end

      result = InterviewResult.create!(
        interview: interview,
        final_status: final_status,
        results_data: result_data,
        rejection_details: rejection_details
      )

      notify_rejection(interview, interview.rejection_reason || rejection.reason) if situation.automatic_judgment? && (early_rejected || rejection.rejected?)

      result
    end

    def notify_rejection(interview, reason)
      method = interview.situation.reject_notify_method

      case method
      when 'email'
        # Day 15以降でActionMailer統合予定
        Rails.logger.info("Rejection notification (email): Interview ##{interview.id} - #{reason}")
      when 'in_app'
        Rails.logger.info("Rejection notification (in_app): Interview ##{interview.id} - #{reason}")
      when 'none'
        # 通知なし
      end
    end

    def generate_summary(responses, language)
      llm = LLMClient.new
      summary = llm.summarize_interview(responses, language: language)

      text = summary[:summary].to_s.strip
      if text.blank? || text.match?(/Summary unavailable|総評の生成に失敗/)
        return fallback_summary(responses, language)
      end

      {
        summary: summary[:summary],
        strengths: summary[:strengths] || [],
        weaknesses: summary[:weaknesses] || [],
        recommendation: summary[:recommendation]
      }
    rescue => e
      Rails.logger.error("Summary generation error: #{e.message}")
      fallback_summary(responses, language)
    end

    def fallback_summary(responses, language)
      scores = responses.map(&:score).compact
      avg = scores.empty? ? 0 : (scores.sum.to_f / scores.size).round(1)

      if language.to_s == 'ja'
        {
          summary: "回答はすべて評価済みです。平均スコアは#{avg}点でした。",
          strengths: ['質問への回答を完了している', '面接フローを最後まで実施できている'],
          weaknesses: ['詳細なAI総評にはOPENAI_API_KEYが必要です'],
          recommendation: 'スコアと個別回答を確認のうえ、最終判断してください。'
        }
      else
        {
          summary: "All answers were evaluated. Average score: #{avg}.",
          strengths: ['Completed all answers', 'Finished the interview flow'],
          weaknesses: ['Detailed AI summary requires OPENAI_API_KEY'],
          recommendation: 'Review scores and individual answers for a final decision.'
        }
      end
    end
  end
end
