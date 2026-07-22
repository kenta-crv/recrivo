# app/services/interview_engine/audio_interview_service.rb
#
# 音声面接のEnd-to-Endフローを管理するサービス。
# コントローラーから呼ばれ、音声入力→STT→テキスト取得→評価送信の一連のパイプラインを統合する。
#
module InterviewEngine
  class AudioInterviewService
    class AudioError < StandardError; end

    def initialize(interview)
      @interview = interview
      @language = interview.language || 'en'
    end

    # 質問の音声データを取得（キャッシュ付き）
    # returns: { question_id:, question_text:, audio_url:, ... }
    def prepare_question(question)
      selector = QuestionSelector.new(@interview)
      selector.prepare_question_audio(question, language: @language)
    end

    # 音声/動画ファイルから回答テキストを取得
    # returns: { transcript:, audio_path:, extracted_audio_path: }
    def process_answer_media(audio_file: nil, video_file: nil, text_answer: nil)
      # テキスト回答がある場合はそのまま返す
      if text_answer.present?
        return { transcript: text_answer, audio_path: nil, extracted_audio_path: nil }
      end

      extracted_audio_path = nil
      target_audio_path = nil

      if audio_file
        target_audio_path = materialize_upload(audio_file)
        extracted_audio_path = target_audio_path
        validate_audio!(target_audio_path)
      elsif video_file
        extracted_audio_path = MediaProcessor.extract_audio_from_video(video_file.path)
        target_audio_path = extracted_audio_path
      else
        raise AudioError, "No answer input provided (audio_file, video_file, or text_answer required)"
      end

      # Whisper は browser webm/opus を拒むことがあるため、先に WAV 16kHz mono へ正規化
      normalized_path = nil
      begin
        normalized_path = MediaProcessor.normalize_audio(target_audio_path)
        stt_path = normalized_path
      rescue InterviewEngine::MediaProcessor::MediaError => e
        Rails.logger.warn("Audio normalize failed, using original: #{e.message}")
        stt_path = target_audio_path
      end

      begin
        MediaProcessor.validate_audio_duration!(stt_path)
      rescue InterviewEngine::MediaProcessor::MediaError => e
        raise AudioError, humanize_media_error(e.message)
      end

      # STT実行（キー無し・TEST_MODEはスタブで継続可能にする）
      transcript = if ENV['OPENAI_API_KEY'].blank? && test_mode?
                     "(音声回答を受信しました。OPENAI_API_KEY未設定のため文字起こしスタブです)"
                   else
                     begin
                       STTClient.new.transcribe(stt_path, language: @language)
                     rescue InterviewEngine::STTClient::STTError => e
                       raise AudioError, humanize_stt_error(e.message)
                     end
                   end

      unless transcript.present?
        raise AudioError, "文字起こし結果が空でした。もう一度はっきり話してください。"
      end

      {
        transcript: transcript,
        audio_path: audio_file&.path,
        extracted_audio_path: [extracted_audio_path, normalized_path].compact
      }
    end

    # 一時ファイルのクリーンアップ
    def cleanup_temp_files(*paths)
      paths.flatten.compact.each do |path|
        File.delete(path) if File.exist?(path)
      rescue => e
        Rails.logger.warn("Failed to delete temp file #{path}: #{e.message}")
      end
    end

    # Situation単位で全質問の音声を事前生成（バッチ用）
    def self.pregenerate_question_audio(situation, language: nil)
      language ||= situation.language || 'en'
      tts_client = TTSClient.new

      # N+1回避: 既存のQuestionAudioを事前ロードし、音声生成済みの質問IDを取得
      existing_question_ids = QuestionAudio
        .where(language: language)
        .joins(:audio_attachment)
        .where(question_id: situation.questions.select(:id))
        .pluck(:question_id)
        .to_set

      situation.questions.order(:order).each do |question|
        next if existing_question_ids.include?(question.id)

        record = QuestionAudio.find_or_initialize_by(question: question, language: language)

        audio_path = tts_client.speak(question.question_text, language: language)
        next if audio_path.nil?

        File.open(audio_path, 'rb') do |file|
          record.audio.attach(
            io: file,
            filename: File.basename(audio_path),
            content_type: 'audio/mpeg'
          )
        end
        record.save!

        File.delete(audio_path) if File.exist?(audio_path)

        Rails.logger.info("Pre-generated audio for question ##{question.id} (#{language})")
      rescue => e
        Rails.logger.error("Failed to pre-generate audio for question ##{question.id}: #{e.message}")
      end
    end

    private

    def test_mode?
      return false if Rails.env.production?
      ENV['AI_INTERVIEW_TEST_MODE'] == 'true'
    end

    # Rack の一時ファイルは拡張子がないことがあり Whisper が弾くため、拡張子付きへコピーする
    def materialize_upload(upload)
      original = upload.respond_to?(:original_filename) ? upload.original_filename.to_s : ''
      ext = File.extname(original).downcase
      ext = '.webm' if ext.blank? || !STTClient::ALLOWED_FORMATS.include?(ext)

      path = File.join(Dir.tmpdir, "interview_upload_#{SecureRandom.hex(8)}#{ext}")
      upload.rewind if upload.respond_to?(:rewind)
      File.open(path, 'wb') do |out|
        if upload.respond_to?(:read)
          IO.copy_stream(upload, out)
        else
          out.write(File.binread(upload.path))
        end
      end
      upload.rewind if upload.respond_to?(:rewind)
      path
    end

    def validate_audio!(audio_path)
      raise AudioError, "音声ファイルが見つかりません" unless File.exist?(audio_path)
      raise AudioError, "音声ファイルが空です。もう一度録音してください。" if File.size(audio_path).zero?

      max_size = Rails.application.config.interview.stt_max_file_size
      if File.size(audio_path) > max_size
        raise AudioError, "音声ファイルが大きすぎます（最大 #{max_size / 1024 / 1024}MB）"
      end
    end

    def humanize_media_error(message)
      case message.to_s
      when /Audio too short/i
        "録音が短すぎます。1秒以上話してから「話し終わり」を押してください。"
      when /Audio too long/i
        "録音が長すぎます。短く区切って話してください。"
      when /Failed to normalize/i
        "音声の変換に失敗しました。別のブラウザで試すか、テキストで入力してください。"
      else
        "音声の処理に失敗しました: #{message}"
      end
    end

    def humanize_stt_error(message)
      case message.to_s
      when /OPENAI_API_KEY/i
        "文字起こしAPIキーが未設定です。テキストで回答するか、管理者に連絡してください。"
      when /Empty transcript/i
        "音声から文字を認識できませんでした。もう一度はっきり話してください。"
      when /Unsupported audio format/i
        "この音声形式は対応していません。もう一度録音してください。"
      else
        "文字起こしに失敗しました: #{message}"
      end
    end
  end
end
