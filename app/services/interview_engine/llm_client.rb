# app/services/interview_engine/llm_client.rb
require 'net/http'
require 'json'

module InterviewEngine
  class LLMClient

    OPENAI_URL = 'https://api.openai.com/v1/chat/completions'
    CLAUDE_URL = 'https://api.anthropic.com/v1/messages'
    RETRY_DELAY_BASE = 1 # seconds (exponential backoff)

    class LLMError < StandardError; end
    class LLMTimeoutError < LLMError; end
    class LLMResponseError < LLMError; end
    class LLMValidationError < LLMError; end

    def initialize(model: nil)
      @model = model || config.llm_model
    end

    # 回答評価（バリデーション・リトライ付き）
    def evaluate_response(question_text, user_answer, language: 'en', question_type: 'open')
      prompt = PromptTemplate.evaluation(
        question_text: question_text,
        user_answer: user_answer,
        language: language,
        question_type: question_type
      )

      result = call_with_retry(prompt, :evaluation)
      ResponseValidator.validate_evaluation!(result)
    rescue ResponseValidator::InvalidResponseError => e
      Rails.logger.error("LLM Evaluation Validation Error: #{e.message}")
      default_error_response
    rescue LLMError => e
      Rails.logger.error("LLM Evaluation Error: #{e.message}")
      default_error_response
    end

    # 面接サマリー生成（バリデーション・リトライ付き）
    def summarize_interview(responses, language: 'en')
      responses_data = responses.map do |r|
        {
          question: r.question.question_text,
          answer: r.audio_transcript,
          score: r.score
        }
      end

      prompt = PromptTemplate.summary(
        responses_data: responses_data,
        language: language
      )

      result = call_with_retry(prompt, :summary)
      ResponseValidator.validate_summary!(result)
    rescue ResponseValidator::InvalidResponseError => e
      Rails.logger.error("LLM Summary Validation Error: #{e.message}")
      default_summary_response
    rescue LLMError => e
      Rails.logger.error("LLM Summary Error: #{e.message}")
      default_summary_response
    end

    # 業種・職種から面接質問を提案
    def suggest_interview_questions(industry:, job_title:, language: 'ja', count: 5, situation_title: nil)
      industry = industry.to_s.strip
      job_title = job_title.to_s.strip
      count = count.to_i.clamp(3, 8)

      if industry.blank? || job_title.blank?
        return fallback_question_suggestions(industry, job_title, language, count)
      end

      if llm_unavailable?
        return fallback_question_suggestions(industry, job_title, language, count)
      end

      prompt = PromptTemplate.question_suggestions(
        industry: industry,
        job_title: job_title,
        language: language,
        count: count,
        situation_title: situation_title
      )

      result = call_with_retry(prompt, :question_suggestions)
      normalize_question_suggestions!(result, count)
    rescue ResponseValidator::InvalidResponseError, LLMError, StandardError => e
      Rails.logger.error("LLM Question Suggestion Error: #{e.class}: #{e.message}")
      fallback_question_suggestions(industry, job_title, language, count)
    end

    # 汎用チャットメソッド（要約生成などで使用）
    def chat(prompt)
      call_llm(prompt)
    end

    private

    def llm_unavailable?
      case @model
      when 'openai'
        ENV['OPENAI_API_KEY'].blank?
      when 'claude'
        ENV['ANTHROPIC_API_KEY'].blank?
      else
        true
      end
    end

    def normalize_question_suggestions!(result, count)
      questions = result.is_a?(Hash) ? result['questions'] || result[:questions] : nil
      raise ResponseValidator::InvalidResponseError, 'questions missing' unless questions.is_a?(Array)

      normalized = questions.filter_map do |item|
        next unless item.is_a?(Hash)

        text = (item['question_text'] || item[:question_text]).to_s.strip
        next if text.blank?

        {
          'question_text' => text.truncate(500),
          'question_type' => 'open',
          'required' => ActiveModel::Type::Boolean.new.cast(item['required'].nil? ? item[:required] : item['required']),
          'category' => (item['category'] || item[:category]).to_s.strip.presence || '一般',
          'reason' => (item['reason'] || item[:reason]).to_s.strip.truncate(200)
        }
      end.first(count)

      raise ResponseValidator::InvalidResponseError, 'no valid questions' if normalized.empty?

      normalized.each_with_index do |q, idx|
        q['required'] = idx < 2 if q['required'].nil?
      end

      { 'questions' => normalized }.with_indifferent_access
    end

    def fallback_question_suggestions(industry, job_title, language, count)
      role = job_title.presence || (language.to_s == 'ja' ? 'この職種' : 'this role')
      industry_label = industry.presence || (language.to_s == 'ja' ? 'この業種' : 'this industry')

      templates = if language.to_s == 'ja'
                    [
                      { text: "これまでのご経験の中で、#{role}として最も成果を出せた事例を教えてください。", category: '経歴', required: true, reason: '実績の具体性を確認します。' },
                      { text: "#{industry_label}の現場で、困難な状況をどう乗り越えたか具体的に教えてください。", category: '課題解決', required: true, reason: '業種文脈での対応力を見ます。' },
                      { text: "#{role}の業務で大切にしている優先順位の付け方を教えてください。", category: '働き方', required: false, reason: '判断基準の傾向を把握します。' },
                      { text: 'チームで意見が割れたとき、どのように合意形成しましたか？', category: 'チームワーク', required: false, reason: '協調性とコミュニケーションを確認します。' },
                      { text: "今後#{role}として伸ばしたいスキルと、その理由を教えてください。", category: '意欲', required: false, reason: '成長意欲と自己理解を見ます。' },
                      { text: "#{industry_label}で働くうえで、お客様や関係者への配慮で意識していることを教えてください。", category: '顧客志向', required: false, reason: '対人姿勢を確認します。' },
                      { text: '締め切りが厳しい案件で、品質を保つために工夫したことを教えてください。', category: '実務', required: false, reason: '実務遂行力を確認します。' },
                      { text: '入社後90日で取り組みたいことを、優先度順に教えてください。', category: '意欲', required: false, reason: '短期目標の具体性を見ます。' }
                    ]
                  else
                    [
                      { text: "Tell me about a time you delivered strong results as a #{role}.", category: 'Experience', required: true, reason: 'Checks concrete achievement.' },
                      { text: "Describe how you handled a difficult situation in #{industry_label}.", category: 'Problem solving', required: true, reason: 'Assesses industry-context resilience.' },
                      { text: "How do you prioritize work in a #{role} role?", category: 'Work style', required: false, reason: 'Reveals judgment criteria.' },
                      { text: 'How do you resolve disagreements within a team?', category: 'Teamwork', required: false, reason: 'Checks collaboration.' },
                      { text: "What skill do you want to grow next as a #{role}, and why?", category: 'Motivation', required: false, reason: 'Checks growth mindset.' },
                      { text: "What do you keep in mind when working with stakeholders in #{industry_label}?", category: 'Stakeholder', required: false, reason: 'Checks interpersonal focus.' },
                      { text: 'How do you protect quality under a tight deadline?', category: 'Execution', required: false, reason: 'Checks practical delivery.' },
                      { text: 'What would you focus on in your first 90 days?', category: 'Motivation', required: false, reason: 'Checks short-term planning.' }
                    ]
                  end

      {
        'questions' => templates.first(count).map do |t|
          {
            'question_text' => t[:text],
            'question_type' => 'open',
            'required' => t[:required],
            'category' => t[:category],
            'reason' => t[:reason]
          }
        end
      }.with_indifferent_access
    end

    # リトライ付きLLM呼び出し
    def call_with_retry(prompt, validation_type)
      last_error = nil

      config.llm_max_retries.times do |attempt|
        begin
          raw_response = call_llm(prompt)
          result = ResponseValidator.extract_json(raw_response)

          if result
            Rails.logger.info("LLM call succeeded on attempt #{attempt + 1}")
            return result
          end

          last_error = "Failed to extract valid JSON (attempt #{attempt + 1})"
          Rails.logger.warn(last_error)
        rescue LLMTimeoutError, LLMResponseError, Net::HTTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
          last_error = e.message
          Rails.logger.warn("LLM retryable error (attempt #{attempt + 1}): #{e.class}: #{e.message}")
        rescue StandardError => e
          # プロキシ/サンドボックス等の予期しない通信失敗もリトライ対象にする
          last_error = e.message
          Rails.logger.warn("LLM unexpected error (attempt #{attempt + 1}): #{e.class}: #{e.message}")
        end

        sleep(RETRY_DELAY_BASE ** (attempt + 1)) if attempt < config.llm_max_retries - 1
      end

      raise LLMValidationError, "All #{config.llm_max_retries} attempts failed: #{last_error}"
    end

    # LLM API呼び出し（モデル切替）
    def call_llm(prompt)
      case @model
      when 'openai'
        call_openai(prompt)
      when 'claude'
        call_claude(prompt)
      else
        raise LLMError, "Unknown model: #{@model}"
      end
    end

    # OpenAI API呼び出し
    def call_openai(prompt)
      api_key = ENV['OPENAI_API_KEY']
      raise LLMError, "OPENAI_API_KEY is not set" if api_key.blank?

      # prompt が単なる文字列で渡された場合のラッパー処理
      formatted_prompt = prompt.is_a?(Hash) ? prompt : { system: 'You are a helpful assistant.', user: prompt.to_s }

      uri = URI(OPENAI_URL)
      http = build_http(uri)

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'

      body = {
        model: config.openai_model,
        messages: [
          { role: 'system', content: formatted_prompt[:system] },
          { role: 'user', content: formatted_prompt[:user] }
        ],
        temperature: config.llm_temperature,
        max_tokens: config.llm_max_tokens,
        response_format: { type: 'json_object' }
      }

      request.body = body.to_json
      response = http.request(request)

      handle_api_response(response, 'OpenAI')

      parsed = JSON.parse(response.body)
      content = parsed.dig('choices', 0, 'message', 'content')
      raise LLMResponseError, "Empty content from OpenAI" if content.blank?

      content
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise LLMTimeoutError, "OpenAI request timed out: #{e.message}"
    rescue JSON::ParserError => e
      raise LLMResponseError, "Failed to parse OpenAI response: #{e.message}"
    end

    # Claude API呼び出し
    def call_claude(prompt)
      api_key = ENV['ANTHROPIC_API_KEY']
      raise LLMError, "ANTHROPIC_API_KEY is not set" if api_key.blank?

      # prompt が単なる文字列で渡された場合のラッパー処理
      formatted_prompt = prompt.is_a?(Hash) ? prompt : { system: 'You are a helpful assistant.', user: prompt.to_s }

      uri = URI(CLAUDE_URL)
      http = build_http(uri)

      request = Net::HTTP::Post.new(uri.path)
      request['x-api-key'] = api_key
      request['anthropic-version'] = '2023-06-01'
      request['Content-Type'] = 'application/json'

      # 2026年現在、完全に有効な現行の主要な3.5 Sonnetの固定バージョンID（claude-sonnet-4-5-20250929）に固定
      claude_model_name = Rails.env.development? ? 'claude-sonnet-4-5-20250929' : config.claude_model

      body = {
        model: claude_model_name,
        max_tokens: config.llm_max_tokens || 4000,
        system: formatted_prompt[:system],
        messages: [
          { role: 'user', content: formatted_prompt[:user] }
        ]
      }

      request.body = body.to_json
      response = http.request(request)

      handle_api_response(response, 'Claude')

      parsed = JSON.parse(response.body)
      content = parsed.dig('content', 0, 'text')
      raise LLMResponseError, "Empty content from Claude" if content.blank?

      content
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise LLMTimeoutError, "Claude request timed out: #{e.message}"
    rescue JSON::ParserError => e
      raise LLMResponseError, "Failed to parse Claude response: #{e.message}"
    end

    # HTTP接続のビルド（タイムアウト設定付き）
    def build_http(uri)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = config.llm_request_timeout
      http.read_timeout = config.llm_request_timeout
      http
    end

    def config
      Rails.application.config.interview
    end

    # APIレスポンスのHTTPステータスチェック
    def handle_api_response(response, provider)
      case response.code.to_i
      when 200..299
        # OK
      when 429
        raise LLMResponseError, "#{provider} rate limit exceeded"
      when 401, 403
        raise LLMError, "#{provider} authentication failed (#{response.code})"
      when 500..599
        raise LLMResponseError, "#{provider} server error (#{response.code})"
      else
        raise LLMError, "#{provider} unexpected response (#{response.code}): #{response.body.truncate(200)}"
      end
    end

    def default_error_response
      {
        relevance_score: 0,
        correctness_score: 0,
        clarity_score: 0,
        final_score: 0,
        passed: false,
        reasoning: '評価に失敗しました。再試行してください。'
      }.with_indifferent_access
    end

    def default_summary_response
      {
        summary: '総評の生成に失敗しました。',
        strengths: [],
        weaknesses: [],
        recommendation: '個別回答とスコアを確認のうえ判断してください。'
      }.with_indifferent_access
    end
  end
end