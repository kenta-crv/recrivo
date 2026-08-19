module Api
  class InterviewsController < ApplicationController
    skip_before_action :verify_authenticity_token
    include ApiErrorHandler
    include FileUploadValidation

    before_action :verify_content_type!, only: [:start, :start_by_token, :submit_answer, :transcribe, :complete, :resume]
    
    # 修正点1: startアクションを厳格認証から除外し、トークン未所持・ゲスト払い出し動線を確保する
    before_action :authenticate_by_token_or_user!, except: [:start, :start_by_token]
    before_action :authenticate_or_create_guest!, only: [:start]
    
    before_action :set_interview, only: [:next_question, :submit_answer, :transcribe, :complete, :status, :resume, :track_event, :evaluate, :faqs]
    before_action :check_session_timeout!, only: [:next_question, :submit_answer, :transcribe]

    # POST /api/interviews/start
    def start
      situation = Situation.active.find_by(id: params[:situation_id])
      unless situation
        return render_api_error('Situation not found', status: :not_found)
      end

      invite_token = params[:invite_token].to_s
      unless invite_token_matches?(situation, invite_token)
        return render_api_error('Invalid or missing invite token', status: :forbidden)
      end

      preview = preview_request?(situation)
      if situation.questions.none?
        return render_api_error(
          I18n.t("recrivo.interview.errors.no_questions"),
          status: :unprocessable_entity,
          reason: "no_questions"
        )
      end

      unless preview
        client = situation.client
        unless client&.can_start_interview?
          return render_api_error(
            client&.interview_limit_message || 'Monthly interview limit reached',
            status: :forbidden,
            reason: 'monthly_limit'
          )
        end
      end

      unless preview || apply_candidate_identity!(situation)
        return # error already rendered
      end

      if preview
        @current_user = find_or_create_preview_user(situation)
      end

      language = params[:language].presence || situation.language || 'en'

      session_manager = InterviewEngine::SessionManager.new(@current_user, situation)
      interview = session_manager.start_interview(language: language, preview: preview)

      InterviewEvent.track!(
        situation: situation,
        interview: interview,
        event_type: preview ? 'preview_start' : 'interview_start',
        session_key: interview.access_token,
        preview: preview
      )

      greeting = build_interview_greeting(
        situation: situation,
        candidate_name: preview ? 'プレビュー' : params[:candidate_name].to_s.strip,
        language: language
      )

      render json: {
        success: true,
        interview_id: interview.id,
        access_token: interview.access_token,
        status: interview.status,
        total_questions: interview.total_questions,
        language: interview.language,
        session_timeout_minutes: situation.session_timeout_minutes,
        remaining_seconds: interview.remaining_seconds,
        greeting: greeting,
        answer_settings: answer_settings_payload(situation),
        preview: preview,
        enable_satisfaction_survey: situation.enable_satisfaction_survey?,
        faqs: situation.situation_faqs.approved.ordered.limit(20).map { |f|
          { id: f.id, question: f.question, answer: f.answer, category: f.category }
        },
        materials_url: situation.recruitment_material.attached? ? rails_blob_path(situation.recruitment_material, only_path: true) : nil,
        job_info: situation.candidate_job_info(detail: true)
      }, status: :created
    rescue InterviewEngine::SessionManager::AlreadyCompletedError => e
      # 1回のみ仕様: 受験済みは「エラー」ではなく「案内」として返す
      render_api_error(
        e.message,
        status: :unprocessable_entity,
        reason: 'already_completed',
        details: { situation_id: params[:situation_id].to_i }
      )
    rescue InterviewEngine::SessionManager::SessionError => e
      render_api_error(e.message, status: :unprocessable_entity)
    end

    # POST /api/interviews/start_by_token
    def start_by_token
      access_token = params[:access_token]
      unless access_token.present?
        return render_api_error('access_token is required', status: :bad_request)
      end

      interview = InterviewEngine::SessionManager.start_by_token(access_token)

      render json: {
        success: true,
        interview_id: interview.id,
        status: interview.status,
        total_questions: interview.total_questions,
        language: interview.language,
        progress: interview.progress_percentage,
        answered_questions: interview.answered_question_count,
        session_timeout_minutes: interview.situation.session_timeout_minutes,
        remaining_seconds: interview.remaining_seconds,
        resume_count: interview.resume_count
      }
    rescue InterviewEngine::SessionManager::TimeoutError => e
      render_api_error(e.message, status: :gone, reason: 'timeout')
    rescue InterviewEngine::SessionManager::ResumeError => e
      render_api_error(e.message, status: :forbidden, reason: 'resume_limit')
    rescue InterviewEngine::SessionManager::AlreadyCompletedError => e
      render_api_error(e.message, status: :unprocessable_entity, reason: 'already_completed')
    rescue InterviewEngine::SessionManager::SessionError => e
      render_api_error(e.message, status: :unprocessable_entity)
    end

    # POST /api/interviews/:id/resume
    def resume
      session_manager = InterviewEngine::SessionManager.new(@interview.user, @interview.situation)
      interview = session_manager.resume_interview(@interview.id)

      render json: {
        success: true,
        interview_id: interview.id,
        status: interview.status,
        progress: interview.progress_percentage,
        answered_questions: interview.answered_question_count,
        total_questions: interview.total_questions,
        remaining_seconds: interview.remaining_seconds,
        resume_count: interview.resume_count
      }
    rescue InterviewEngine::SessionManager::ResumeError => e
      render_api_error(e.message, status: :forbidden)
    end

    # GET /api/interviews/:id/next_question
    def next_question
      unless @interview.in_progress?
        return render_api_error('Interview not in progress', status: :bad_request)
      end

      selector = InterviewEngine::QuestionSelector.new(@interview)

      if selector.no_askable_questions?
        return render_api_error(
          I18n.t("recrivo.interview.errors.no_questions"),
          status: :unprocessable_entity,
          reason: "no_questions"
        )
      end

      unless selector.should_continue_interview?
        return render json: {
          success: true,
          message: 'All questions answered',
          interview_complete: true
        }
      end

      question = selector.get_next_question
      language = params[:language].presence || @interview.language || 'en'

      question_payload = begin
        # TTS が長引くと「読み込み中」が異常に長く見えるため上限を設ける
        Timeout.timeout(25) do
          selector.prepare_question_audio(question, language: language)
        end
      rescue Timeout::Error => e
        Rails.logger.warn("TTS timed out for question #{question.id}: #{e.message}")
        selector.get_question_text(question).merge(audio_url: nil, tts_fallback: true)
      rescue InterviewEngine::TTSClient::TTSError => e
        Rails.logger.warn("TTS unavailable, falling back to text: #{e.message}")
        selector.get_question_text(question).merge(audio_url: nil, tts_fallback: true)
      end

      @interview.touch_activity!

      InterviewEvent.track!(
        situation: @interview.situation,
        interview: @interview,
        event_type: "question_view",
        question_id: question.id,
        session_key: @interview.access_token,
        preview: @interview.preview?
      )

      render json: {
        success: true,
        question: question_payload,
        remaining_seconds: @interview.remaining_seconds
      }
    end

    # POST /api/interviews/:id/transcribe
    # 回答確定前に、録音を文字起こししてテキスト欄へ返す
    def transcribe
      audio_file = params[:audio_file]
      unless audio_file
        return render_api_error('audio_file is required', status: :bad_request)
      end

      validate_audio_upload!(audio_file)

      audio_service = InterviewEngine::AudioInterviewService.new(@interview)
      @_extracted_audio_path = nil
      media_result = audio_service.process_answer_media(audio_file: audio_file)
      @_extracted_audio_path = media_result[:extracted_audio_path]

      @interview.touch_activity!

      render json: {
        success: true,
        transcript: media_result[:transcript]
      }
    rescue InterviewEngine::AudioInterviewService::AudioError,
           InterviewEngine::STTClient::STTError,
           InterviewEngine::MediaProcessor::MediaError => e
      render_api_error(e.message, status: :bad_request)
    ensure
      if @_extracted_audio_path
        InterviewEngine::AudioInterviewService.new(@interview).cleanup_temp_files(@_extracted_audio_path)
      end
    end

    # POST /api/interviews/:id/submit_answer
    def submit_answer
      question_id = params[:question_id]
      audio_file = params[:audio_file]
      video_file = params[:video_file]
      text_answer = params[:text_answer].presence || params[:selected_option].presence
      situation = @interview.situation

      unless question_id && (audio_file || video_file || text_answer.present?)
        return render_api_error('Missing question_id or answer input', status: :bad_request)
      end

      if text_answer.present? && !situation.allow_text_answer? && audio_file.blank? && video_file.blank?
        return render_api_error('Text answers are not allowed for this interview', status: :forbidden)
      end

      if audio_file.present? && !situation.allow_voice_answer?
        return render_api_error('Voice answers are not allowed for this interview', status: :forbidden)
      end

      if video_file.present? && !situation.record_camera?
        return render_api_error('Camera recording is not enabled for this interview', status: :forbidden)
      end

      # テキスト不可かつ音声可の場合は、音声（または録画）必須
      if !situation.allow_text_answer? && situation.allow_voice_answer? && audio_file.blank? && video_file.blank?
        return render_api_error('Voice answer is required for this interview', status: :bad_request)
      end

      # ファイルアップロードバリデーション
      validate_audio_upload!(audio_file)
      validate_video_upload!(video_file)

      question = Question.find_by(id: question_id, situation_id: @interview.situation_id)
      unless question
        return render_api_error('Question not found', status: :not_found)
      end

      # 二重回答防止: interviewレコードをロックして重複チェック
      @interview.with_lock do
        existing_response = @interview.interview_responses.find_by(question_id: question_id)
        if existing_response
          render_api_error('Question already answered', status: :conflict)
          return
        end
      end

      # ロック外で音声処理を実行（長時間処理のためロック外で行う）
      audio_service = InterviewEngine::AudioInterviewService.new(@interview)
      @_extracted_audio_path = nil
      media_result = audio_service.process_answer_media(
        audio_file: audio_file,
        video_file: video_file,
        text_answer: text_answer
      )
      @_extracted_audio_path = media_result[:extracted_audio_path]

      response = @interview.interview_responses.create!(
        question: question,
        audio_transcript: media_result[:transcript],
        evaluation_status: :pending
      )

      attach_media(response, audio_file, video_file, media_result[:extracted_audio_path])

      if test_mode?
        EvaluateInterviewResponseJob.perform_now(response.id)
      else
        EvaluateInterviewResponseJob.perform_later(response.id)
      end
      @interview.touch_activity!

      InterviewEvent.track!(
        situation: @interview.situation,
        interview: @interview,
        event_type: "answer_submit",
        question_id: question.id,
        session_key: @interview.access_token,
        preview: @interview.preview?,
        metadata: { response_id: response.id }
      )

      render json: {
        success: true,
        message: 'Response submitted for evaluation',
        response_id: response.id,
        remaining_seconds: @interview.remaining_seconds
      }, status: :created
    rescue InterviewEngine::AudioInterviewService::AudioError,
           InterviewEngine::STTClient::STTError,
           InterviewEngine::MediaProcessor::MediaError => e
      render_api_error(e.message, status: :bad_request)
    ensure
      # 例外時でも一時ファイルをクリーンアップ
      if @_extracted_audio_path
        InterviewEngine::AudioInterviewService.new(@interview).cleanup_temp_files(@_extracted_audio_path)
      end
    end

    # POST /api/interviews/:id/complete
    def complete
      unless @interview.in_progress?
        return render_api_error('Interview not in progress', status: :bad_request)
      end

      session_manager = InterviewEngine::SessionManager.new(@interview.user, @interview.situation)
      result = session_manager.complete_interview(@interview.id)

      @interview.reload

      InterviewEvent.track!(
        situation: @interview.situation,
        interview: @interview,
        event_type: "interview_complete",
        session_key: @interview.access_token,
        preview: @interview.preview?
      )

      data = result.results_data || {}
      lang = @interview.language.to_s
      hide_eval = @interview.situation.hide_result_from_candidate?
      failure_reason = data['failure_reason'] || data[:failure_reason] || @interview.rejection_reason
      message = if hide_eval
                  lang == 'ja' ? '面接情報を受け付けました。結果は後日ご連絡します。' : 'We received your interview. We will contact you with the result later.'
                elsif lang == 'ja'
                  if result.failed? && failure_reason.present?
                    "面接が完了しました。不合格理由: #{failure_reason}"
                  else
                    '面接が完了しました。'
                  end
                else
                  if result.failed? && failure_reason.present?
                    "Interview completed. Failure reason: #{failure_reason}"
                  else
                    'Interview completed'
                  end
                end

      result_payload = {
        interview_id: @interview.id,
        judgment_mode: @interview.situation.judgment_mode,
        candidate_result_visibility: @interview.situation.candidate_result_visibility,
        preview: @interview.preview?,
        enable_satisfaction_survey: @interview.situation.enable_satisfaction_survey?,
        faqs: @interview.situation.situation_faqs.approved.ordered.limit(20).map { |f|
          { id: f.id, question: f.question, answer: f.answer, category: f.category }
        },
        materials_url: @interview.situation.recruitment_material.attached? ? rails_blob_path(@interview.situation.recruitment_material, only_path: true) : nil,
        job_info: @interview.situation.candidate_job_info(detail: true)
      }

      unless hide_eval
        result_payload.merge!(
          final_status: result.final_status,
          average_score: data['average_score'] || data[:average_score],
          passing_score: data['passing_score'] || data[:passing_score],
          total_questions: data['total_questions'] || data[:total_questions],
          answered_questions: data['answered_questions'] || data[:answered_questions],
          summary: data['summary'] || data[:summary],
          strengths: data['strengths'] || data[:strengths] || [],
          weaknesses: data['weaknesses'] || data[:weaknesses] || [],
          recommendation: data['recommendation'] || data[:recommendation],
          rejected: @interview.rejected?,
          rejection_reason: failure_reason,
          failure_reason: failure_reason
        )
      end

      render json: {
        success: true,
        message: message,
        result: result_payload
      }
    rescue InterviewEngine::SessionManager::SessionError => e
      render_api_error(e.message, status: :unprocessable_entity)
    end

    # POST /api/interviews/:id/track_event
    def track_event
      event_type = params[:event_type].to_s
      unless InterviewEvent::EVENT_TYPES.include?(event_type)
        return render_api_error('Invalid event_type', status: :bad_request)
      end

      InterviewEvent.track!(
        situation: @interview.situation,
        interview: @interview,
        event_type: event_type,
        question_id: params[:question_id],
        session_key: @interview.access_token,
        preview: @interview.preview? || ActiveModel::Type::Boolean.new.cast(params[:preview]),
        metadata: params[:metadata].presence || {}
      )

      render json: { success: true }
    end

    # POST /api/interviews/:id/evaluate — 満足度
    def evaluate
      if @interview.preview?
        return render json: { success: true, message: 'preview', ok: true }
      end

      rating = params[:rating].to_i
      unless (1..5).cover?(rating)
        return render_api_error('rating must be 1-5', status: :bad_request)
      end

      @interview.update!(
        satisfaction_rating: rating,
        satisfaction_feedback: params[:feedback].to_s.truncate(2000)
      )

      InterviewEvent.track!(
        situation: @interview.situation,
        interview: @interview,
        event_type: "satisfaction_submit",
        session_key: @interview.access_token,
        metadata: { rating: rating }
      )

      render json: { success: true }
    end

    # GET /api/interviews/:id/faqs
    def faqs
      list = @interview.situation.situation_faqs.approved.ordered
      render json: {
        success: true,
        faqs: list.map { |f| { id: f.id, question: f.question, answer: f.answer, category: f.category } }
      }
    end

    # GET /api/interviews/:id/status
    def status
      session_manager = InterviewEngine::SessionManager.new(@interview.user, @interview.situation)
      state = session_manager.get_interview_state(@interview.id)

      state_with_rejection = state.merge(
        language: @interview.language,
        candidate_result_visibility: @interview.situation.candidate_result_visibility
      )

      unless @interview.situation.hide_result_from_candidate?
        state_with_rejection = state_with_rejection.merge(
          rejected: @interview.rejected?,
          rejection_reason: @interview.rejection_reason
        )
      end

      if (result = @interview.interview_result)
        data = result.results_data || {}
        unless @interview.situation.hide_result_from_candidate?
          state_with_rejection = state_with_rejection.merge(
            final_status: result.final_status,
            average_score: data['average_score'] || data[:average_score],
            summary: data['summary'] || data[:summary],
            strengths: data['strengths'] || data[:strengths] || [],
            weaknesses: data['weaknesses'] || data[:weaknesses] || [],
            recommendation: data['recommendation'] || data[:recommendation]
          )
        end
      end

      render json: {
        success: true,
        state: state_with_rejection
      }
    end

    private

    # Content-Type検証（JSON/multipart以外を拒否）
    def verify_content_type!
      return if request.content_type.blank? # GETリクエスト等

      allowed = ['application/json', 'multipart/form-data']
      content_type = request.content_type&.split(';')&.first
      unless allowed.include?(content_type)
        render_api_error(
          "Unsupported Content-Type: #{content_type}",
          status: :unsupported_media_type
        )
      end
    end

    # トークン or Devise認証の統合
    def authenticate_by_token_or_user!
      token = request.headers['X-Interview-Token'] || params[:access_token]

      if token.present?
        interview = Interview.by_token(token).first
        if interview
          @current_user = interview.user
          return
        end
      end

      if test_mode?
        @current_user = User.find_by(email: 'test@interview.com') || User.first
        return
      end

      # Devise ログイン時も受験者は User のみ（Client/Admin を混ぜない）
      if user_signed_in?
        @current_user = current_user
        return
      end

      respond_to do |format|
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
        format.all  { redirect_to new_user_session_path, alert: 'セッションが終了しました。ログインしてください。' }
      end
    end

    # APIキーによる認証
    def authenticate_by_api_key!
      api_key = extract_api_key

      configured_key = ENV['INTERVIEW_API_KEY']
      if configured_key.blank?
        render_api_error('API key authentication is not configured', status: :service_unavailable)
        return
      end

      unless ActiveSupport::SecurityUtils.secure_compare(api_key, configured_key)
        render_api_error('Invalid API key', status: :unauthorized)
        return
      end

      # APIキー認証時はデフォルトAPIユーザーを使用
      @current_user = User.find_by(email: 'api@interview.com') || User.first

      unless @current_user
        render_api_error('No user found. Create a user first.', status: :unprocessable_entity)
      end
    end

    # start用: 認証済みユーザーがいればそのまま、いなければゲストユーザーを割り当て
    # 候補者身元（name/email）は apply_candidate_identity! で確定する
    def authenticate_or_create_guest!
      token = request.headers['X-Interview-Token'] || params[:access_token]
      if token.present?
        interview = Interview.by_token(token).first
        if interview
          @current_user = interview.user
          return
        end
      end

      if extract_api_key.present?
        authenticate_by_api_key!
        return
      end

      # 受験者は常に User（ゲスト含む）。Client/Admin を User FK に載せない
      if user_signed_in?
        @current_user = current_user
        return
      end

      @current_user = find_or_create_browser_guest_user
    end

    # 氏名・メール等で受験者を特定（シナリオの登録項目設定に従う）
    def apply_candidate_identity!(situation = nil)
      situation ||= Situation.active.find_by(id: params[:situation_id])
      return false unless situation

      if situation.skip_candidate_registration?
        @current_user ||= find_or_create_browser_guest_user
        return true
      end

      values = {
        "name" => params[:candidate_name].to_s.strip,
        "email" => params[:candidate_email].to_s.strip.downcase,
        "tel" => params[:candidate_tel].to_s.strip,
        "address" => params[:candidate_address].to_s.strip,
        "job_title" => params[:candidate_job_title].to_s.strip,
        "company" => params[:candidate_company].to_s.strip,
        "url" => params[:candidate_url].to_s.strip
      }

      missing = situation.required_candidate_info_fields.select { |key| values[key].blank? }
      if missing.any?
        labels = missing.map { |k| SituationCandidateRegistration::FIELD_LABELS[k] || k }.join("・")
        render_api_error("#{labels}は必須です", status: :bad_request)
        return false
      end

      email = values["email"]
      if email.present? && !email.match?(URI::MailTo::EMAIL_REGEXP)
        render_api_error('メールアドレスの形式が正しくありません', status: :bad_request)
        return false
      end

      attrs = {}
      situation.visible_candidate_info_fields.each do |key|
        next if key == "email"
        attrs[key.to_sym] = values[key] if values[key].present?
      end

      if email.blank?
        render_api_error('メールアドレスは必須です', status: :bad_request)
        return false
      end

      existing = User.find_by(email: email)
      if existing
        existing.update!(attrs)
        @current_user = existing
      elsif @current_user&.guest?
        @current_user.update!(attrs.merge(email: email))
      else
        @current_user = User.create!(
          attrs.merge(
            email: email,
            password: SecureRandom.hex(16),
            job_title: attrs[:job_title].presence || 'Candidate'
          )
        )
      end

      InterviewEvent.track!(
        situation: situation,
        event_type: "registration_submit",
        metadata: { fields: situation.visible_candidate_info_fields }
      )
      true
    rescue ActiveRecord::RecordInvalid => e
      render_api_error(e.message, status: :unprocessable_entity)
      false
    end

    def preview_request?(situation)
      return false unless ActiveModel::Type::Boolean.new.cast(params[:preview])
      return true if acting_as_admin?
      return true if client_signed_in? && situation.client_id == current_client.id

      false
    end

    def find_or_create_preview_user(situation)
      email = "preview_client_#{situation.client_id}@interview.local"
      User.find_or_create_by!(email: email) do |u|
        u.name = "プレビュー"
        u.password = SecureRandom.hex(16)
        u.job_title = "Preview"
      end
    end

    # ブラウザ単位で一意なゲストユーザーを払い出す（共有ゲスト問題の解消）
    def find_or_create_browser_guest_user
      guest_id = cookies.encrypted[:ai_interview_guest_id]
      if guest_id.blank?
        guest_id = SecureRandom.hex(16)
        cookies.encrypted[:ai_interview_guest_id] = {
          value: guest_id,
          expires: 30.days.from_now,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
      end

      email = "guest_#{guest_id}@interview.local"
      begin
        User.find_or_create_by!(email: email) do |u|
          u.name = "Guest-#{guest_id[0, 6]}"
          u.password = SecureRandom.hex(16)
          u.job_title = "Candidate" if u.respond_to?(:job_title=)
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        User.find_by!(email: email)
      end
    end

    # Authorization: Bearer <key> または X-API-Key ヘッダーからAPIキーを抽出
    def extract_api_key
      auth_header = request.headers['Authorization']
      if auth_header&.start_with?('Bearer ')
        return auth_header.sub('Bearer ', '')
      end

      request.headers['X-API-Key']
    end

    def set_interview
      @interview = Interview.find_by(id: params[:id])
      unless @interview
        render_api_error('Interview not found', status: :not_found)
        return
      end
      authorize_interview!
    end

    # 操作前のタイムアウトチェック
    def check_session_timeout!
      return unless @interview&.in_progress?

      if @interview.timed_out?
        @interview.abandon!
        render_api_error(
          'Interview session has timed out',
          status: :gone,
          reason: 'timeout',
          details: { resumable: @interview.resumable? }
        )
      end
    end

    def test_mode?
      return false if Rails.env.production?
      ENV['AI_INTERVIEW_TEST_MODE'] == 'true'
    end

    def invite_token_matches?(situation, token)
      expected = situation.invite_token.to_s
      return false if token.blank? || expected.blank?
      return false unless token.bytesize == expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(token, expected)
    end

    def build_interview_greeting(situation:, candidate_name:, language:)
      company = situation.client&.company.presence || '弊社'
      title = situation.title.to_s
      name = candidate_name.presence || '候補者'
      text = if language.to_s == 'ja'
               "#{name}さん、本日は#{company}の採用面接へお越しいただき、ありがとうございます。" \
                 "これから「#{title}」の面接を始めます。" \
                 "質問は音声でお伝えしますので、内容をよく聞いてからお答えください。それでは始めましょう。"
             else
               "Hello #{name}, thank you for joining #{company}'s interview today. " \
                 "We will now begin \"#{title}\". Please listen carefully and answer each question. Let's begin."
             end

      # 挨拶も質問と同じくサーバーTTS（ブラウザTTSはChromeでcanceledになりやすい）
      audio_url = begin
        Timeout.timeout(12) { synthesize_greeting_audio(text, language) }
      rescue Timeout::Error
        Rails.logger.warn('Greeting TTS timed out')
        nil
      end

      { text: text, audio_url: audio_url, company: company }
    end

    def synthesize_greeting_audio(text, language)
      return nil if ENV['OPENAI_API_KEY'].blank?

      path = InterviewEngine::TTSClient.new.speak(text, language: language)
      return nil if path.blank?

      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(path, 'rb'),
        filename: "greeting_#{SecureRandom.hex(6)}.mp3",
        content_type: 'audio/mpeg'
      )
      File.delete(path) if File.exist?(path)
      Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    rescue InterviewEngine::TTSClient::TTSError => e
      Rails.logger.warn("Greeting TTS failed: #{e.message}")
      nil
    rescue => e
      Rails.logger.warn("Greeting audio upload failed: #{e.message}")
      nil
    end

    def authorize_interview!
      return if test_mode?

      token = request.headers['X-Interview-Token'] || params[:access_token]
      if token.present?
        if @interview.access_token.present? &&
           ActiveSupport::SecurityUtils.secure_compare(token, @interview.access_token)
          return
        else
          render_api_error('Unauthorized', status: :forbidden)
          return
        end
      end

      unless @current_user && @interview.user_id == @current_user.id
        render_api_error('Unauthorized', status: :forbidden)
      end
    end

    def attach_media(response, audio_file, video_file, extracted_audio_path)
      if audio_file
        response.answer_audio.attach(audio_file)
      elsif extracted_audio_path
        File.open(extracted_audio_path, 'rb') do |file|
          response.answer_audio.attach(
            io: file,
            filename: File.basename(extracted_audio_path),
            content_type: 'audio/wav'
          )
        end
      end

      response.answer_video.attach(video_file) if video_file
    end

    def answer_settings_payload(situation)
      {
        allow_text_answer: situation.allow_text_answer?,
        allow_voice_answer: situation.allow_voice_answer?,
        record_camera: situation.record_camera?
      }
    end
  end
end