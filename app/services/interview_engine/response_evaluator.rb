# app/services/interview_engine/response_evaluator.rb
module InterviewEngine
  class ResponseEvaluator
    # DEFAULT_PASS_THRESHOLD は config/initializers/interview_config.rb で管理

    def initialize(interview_response, language: 'en')
      @response = interview_response
      @language = language
      @interview = interview_response.interview
      @question = interview_response.question
      @situation = @interview.situation
    end

    # Evaluate a single response from user
    def evaluate
      return if @response.audio_transcript.blank?

      @response.update!(evaluation_status: :evaluating)

      evaluation = if @question.multiple_choice?
                     evaluate_multiple_choice
                   elsif openai_available?
                     llm_result = llm_evaluate
                     if llm_result[:reasoning].to_s.match?(/Evaluation failed|評価に失敗/)
                       Rails.logger.warn('LLM evaluation failed; falling back to offline heuristic')
                       offline_heuristic_evaluation.merge(
                         reasoning: "LLM評価失敗のためオフライン評価: #{llm_result[:reasoning]}"
                       )
                     else
                       llm_result
                     end
                   elsif test_mode?
                     offline_heuristic_evaluation
                   else
                     raise StandardError, 'OPENAI_API_KEY is not set (evaluation unavailable)'
                   end

      ActiveRecord::Base.transaction do
        update_response_with_evaluation(evaluation)
      end

      check_rejection

      @response
    rescue => e
      Rails.logger.error("Response Evaluation Error: #{e.message}")
      @response.update!(evaluation_status: :failed)
      raise
    end

    private

    def update_response_with_evaluation(evaluation)
      # 意図的にLLMが返すfinal_scoreを無視し、加重平均で再計算する。
      # LLMのfinal_scoreは各基準スコアと整合しない場合があるため、
      # サーバー側で一貫した算出ロジックを適用する。
      final_score = calculate_weighted_score(evaluation)

      threshold = pass_threshold
      passed = final_score >= threshold

      @response.update!(
        relevance_score: evaluation[:relevance_score],
        correctness_score: evaluation[:correctness_score],
        clarity_score: evaluation[:clarity_score],
        final_score: final_score,
        passed: passed,
        ai_reasoning: evaluation[:reasoning],
        evaluation_status: :completed
      )
    end

    def test_mode?
      ENV['AI_INTERVIEW_TEST_MODE'] == 'true'
    end

    def openai_available?
      ENV['OPENAI_API_KEY'].to_s.strip.present?
    end

    # APIキー無しのオフライン用。内容を見ない固定82点は使わない。
    def offline_heuristic_evaluation
      answer = @response.audio_transcript.to_s.strip
      question = @question.question_text.to_s

      length_score = case answer.length
                     when 0..19 then 15
                     when 20..49 then 35
                     when 50..119 then 55
                     when 120..249 then 70
                     else 78
                     end

      # テンプレ／無関係な短文は大幅減点
      junk = answer.match?(/これはE2Eテスト|テスト回答|asdf|xxx|適当|わからない|特にない/i)
      length_score = [length_score - 40, 5].max if junk

      q_tokens = question.scan(/[\p{Han}\p{Katakana}\p{Hiragana}A-Za-z0-9]{2,}/)
      overlap = q_tokens.count { |t| answer.include?(t) }
      relevance = if answer.length < 20
                    20
                  elsif overlap >= 3
                    [60 + overlap * 5, 90].min
                  elsif overlap >= 1
                    50
                  else
                    junk ? 15 : 35
                  end

      clarity = answer.length >= 80 ? 75 : (answer.length >= 40 ? 55 : 30)
      correctness = junk ? 10 : [(length_score + relevance) / 2, 85].min

      {
        relevance_score: relevance,
        correctness_score: correctness,
        clarity_score: clarity,
        final_score: 0,
        passed: false,
        reasoning: 'Offline heuristic evaluation (no OpenAI key)'
      }.with_indifferent_access
    end

    def llm_evaluate
      llm = LLMClient.new
      llm.evaluate_response(
        @question.question_text,
        @response.audio_transcript,
        language: @language,
        question_type: 'open'
      )
    end

    def calculate_weighted_score(evaluation)
      cfg = Rails.application.config.interview
      weights = {
        relevance: cfg.eval_weight_relevance,
        correctness: cfg.eval_weight_correctness,
        clarity: cfg.eval_weight_clarity
      }

      score = (
        (evaluation[:relevance_score].to_i * weights[:relevance]) +
        (evaluation[:correctness_score].to_i * weights[:correctness]) +
        (evaluation[:clarity_score].to_i * weights[:clarity])
      ).round(2)

      [score, 100].min # Cap at 100
    end

    def check_rejection
      @interview.reload
      return unless @interview.in_progress?

      judge = RejectJudge.new(@interview)
      decision = judge.judge_after_response(@response)

      if decision.rejected?
        judge.apply_rejection!(decision)
        # 通知はトランザクション外で実行
        notify_rejection_via_session_manager(decision.reason)
      end
    end

    def notify_rejection_via_session_manager(reason)
      SessionManager.new(@interview.user, @situation)
                    .send(:notify_rejection, @interview, reason)
    rescue => e
      Rails.logger.error("Rejection notification failed: #{e.message}")
    end

    def pass_threshold
      @situation&.min_required_score || Rails.application.config.interview.default_pass_threshold
    end

    def evaluate_multiple_choice
      options = @question.parsed_options
      choices = options['choices'] || options[:choices] || []
      correct = options['correct'] || options[:correct]

      # 正解未設定（キー欠落 / nil / 空白のみ）は情報収集型とみなし満点扱い。
      # 管理画面でも「正解の選択肢（任意）」と明示されているため、
      # 未設定の場合に不合格とするのは仕様と矛盾する。
      if correct.nil? || correct.to_s.strip.empty?
        return {
          relevance_score: 100,
          correctness_score: 100,
          clarity_score: 100,
          final_score: 100,
          passed: true,
          reasoning: 'Informational choice question (no correct answer defined)'
        }.with_indifferent_access
      end

      selected = @response.audio_transcript.to_s.strip.downcase
      correct_choice = resolve_correct_choice(correct, choices)

      passed = !correct_choice.nil? && selected == correct_choice.downcase
      score = passed ? 100 : 0

      {
        relevance_score: score,
        correctness_score: score,
        clarity_score: score,
        final_score: score,
        passed: passed,
        reasoning: passed ? 'Correct option selected' : 'Incorrect option selected'
      }.with_indifferent_access
    end

    def resolve_correct_choice(correct, choices)
      return nil if correct.nil?

      if correct.is_a?(Integer)
        choices[correct]
      else
        correct.to_s
      end
    end
  end
end
