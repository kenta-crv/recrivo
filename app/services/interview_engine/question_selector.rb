# app/services/interview_engine/question_selector.rb
module InterviewEngine
  class QuestionSelector
    def initialize(interview)
      @interview = interview
      @situation = interview.situation
    end

    # Get next eligible question (considering branching rules)
    def get_next_question
      next_q = eligible_questions.first

      raise "All questions answered" if next_q.nil?
      raise "No questions in situation" if @situation.questions.empty?

      next_q
    end

    # Get question text and generate TTS audio
    def prepare_question_audio(question, language: 'en')
      audio_record = ensure_question_audio(question, language)

      {
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        audio_url: audio_record&.audio&.attached? ? audio_url(audio_record.audio) : nil,
        order: question.order,
        required: question.required?,
        total_questions: total_eligible_count,
        options: question.multiple_choice? ? question.parsed_options : nil,
        avatar_url: avatar_url
      }
    end

    # Get question without audio (text only)
    def get_question_text(question)
      {
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        order: question.order,
        required: question.required?,
        total_questions: total_eligible_count,
        options: question.multiple_choice? ? question.parsed_options : nil,
        avatar_url: avatar_url
      }
    end

    # Check if interview should continue
    def should_continue_interview?
      eligible_questions.any?
    end

    # 未回答のまま出題できる質問が1問もない（未公開のみ、または分岐ですべて除外）
    def no_askable_questions?
      eligible_questions.empty? && @interview.interview_responses.none?
    end

    private

    # All unanswered published questions (no branching filter)
    def unanswered_questions
      @interview.situation.questions.for_interview.where.not(
        id: @interview.interview_responses.select(:question_id)
      )
    end

    def eligible_questions
      unanswered = unanswered_questions.to_a
      filtered = unanswered.select { |q| evaluate_branching_rules(q) }
      return filtered if filtered.any?
      return unanswered.first(1) if unanswered.any? && @interview.interview_responses.none?

      filtered
    end

    # Total count of eligible questions (answered + remaining eligible)
    def total_eligible_count
      answered_count = @interview.interview_responses.count
      answered_count + eligible_questions.size
    end

    # Evaluate branching rules for a question
    # Returns true if the question should be included
    def evaluate_branching_rules(question)
      return true unless question.has_branching_rules?

      rules = question.parsed_branching_rules
      return true if rules.nil?

      conditions = Array(rules[:conditions])
      default_action = rules[:default_action] || 'include'
      question_order = question.order.to_i

      # 自分以前の質問を参照できない条件は、開始時点で全問除外になるので無視する
      usable = conditions.select do |condition|
        source_order = condition[:source_question_order].to_i
        source_order.positive? && (question_order.zero? || source_order < question_order)
      end

      return true if usable.blank?

      usable.each do |condition|
        result = evaluate_condition(condition)
        action = condition[:action] || 'include'

        if result
          return action == 'include'
        end
      end

      default_action == 'include'
    end

    # Evaluate a single branching condition
    def evaluate_condition(condition)
      source_order = condition[:source_question_order]
      return false if source_order.nil?

      response = find_response_for_question_order(source_order)

      case condition[:type]
      when 'selected_option'
        return false if response.nil?
        response.audio_transcript.to_s.strip.downcase == condition[:value].to_s.strip.downcase
      when 'score_above'
        return false if response.nil? || response.final_score.nil?
        response.final_score >= condition[:value].to_f
      when 'score_below'
        return false if response.nil? || response.final_score.nil?
        response.final_score < condition[:value].to_f
      when 'answered'
        response.present?
      else
        false
      end
    end

    # Find InterviewResponse by question order number
    def find_response_for_question_order(order)
      question = @situation.questions.find_by(order: order)
      return nil unless question

      @interview.interview_responses.find_by(question: question)
    end

    def ensure_question_audio(question, language)
      record = QuestionAudio.find_or_initialize_by(question: question, language: language)
      if record.audio.attached?
        # 壊れた添付（closed stream等）は作り直す
        begin
          return record if record.audio.blob&.byte_size.to_i > 0 && record.audio.blob.service.exist?(record.audio.blob.key)
        rescue StandardError
          # fall through to regenerate
        end
        record.audio.purge
      end

      # キー未設定時のみ TTS スキップ（TEST_MODEでもキーがあれば音声生成する）
      if ENV['OPENAI_API_KEY'].blank?
        return record
      end

      tts_client = TTSClient.new
      audio_path = tts_client.speak(question.question_text, language: language)
      return record if audio_path.nil?

      audio_bytes = File.binread(audio_path)
      File.delete(audio_path) if File.exist?(audio_path)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(audio_bytes),
        filename: "question_#{SecureRandom.hex(6)}.mp3",
        content_type: 'audio/mpeg'
      )
      record.audio.attach(blob)
      record.save!
      record
    end

    def test_mode?
      return false if Rails.env.production?
      ENV['AI_INTERVIEW_TEST_MODE'] == 'true'
    end

    def audio_url(audio_attachment)
      Rails.application.routes.url_helpers.rails_blob_path(audio_attachment, only_path: true)
    end

    def avatar_url
      begin
        ActionController::Base.helpers.asset_path('image.png')
      rescue Sprockets::Rails::Helper::AssetNotFound
        nil
      end
    end
  end
end
