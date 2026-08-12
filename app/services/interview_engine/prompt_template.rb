# app/services/interview_engine/prompt_template.rb
module InterviewEngine
  class PromptTemplate
    SUPPORTED_LANGUAGES = %w[en ja].freeze

    class << self
      # 回答評価用プロンプト
      def evaluation(question_text:, user_answer:, language: 'en', question_type: 'open')
        lang = normalize_language(language)

        system_message = build_system_message(:evaluation, lang)
        user_message = if question_type == 'open'
                         build_open_evaluation(question_text, user_answer, lang)
                       else
                         build_choice_evaluation(question_text, user_answer, lang)
                       end

        { system: system_message, user: user_message }
      end

      # 面接サマリー用プロンプト
      def summary(responses_data:, language: 'en')
        lang = normalize_language(language)

        system_message = build_system_message(:summary, lang)
        user_message = build_summary_message(responses_data, lang)

        { system: system_message, user: user_message }
      end

      # 業種・職種からの面接質問提案
      def question_suggestions(industry:, job_title:, language: 'ja', count: 5, situation_title: nil)
        lang = normalize_language(language)
        system_message = build_system_message(:question_suggestions, lang)
        user_message = build_question_suggestions_message(
          industry: industry,
          job_title: job_title,
          language: lang,
          count: count,
          situation_title: situation_title
        )
        { system: system_message, user: user_message }
      end

      # 求人テキストからの基本情報・FAQ抽出
      def job_posting_extraction(source_text:, language: 'ja')
        lang = normalize_language(language)
        system_message = build_system_message(:job_posting_extraction, lang)
        user_message = build_job_posting_extraction_message(source_text: source_text, language: lang)
        { system: system_message, user: user_message }
      end

      # 期待するJSONスキーマの定義
      def expected_schema(type)
        case type
        when :evaluation
          {
            required_keys: %w[relevance_score correctness_score clarity_score final_score passed reasoning],
            score_keys: %w[relevance_score correctness_score clarity_score final_score],
            boolean_keys: %w[passed],
            string_keys: %w[reasoning],
            score_range: 0..100
          }
        when :summary
          {
            required_keys: %w[summary strengths weaknesses recommendation],
            string_keys: %w[summary recommendation],
            array_keys: %w[strengths weaknesses]
          }
        when :question_suggestions
          {
            required_keys: %w[questions],
            array_keys: %w[questions]
          }
        when :job_posting_extraction
          {
            required_keys: %w[job_summary],
            string_keys: %w[job_title industry employment_type location salary_text job_summary requirements_text selection_flow],
            array_keys: %w[faqs]
          }
        else
          raise ArgumentError, "Unknown schema type: #{type}"
        end
      end

      private

      def normalize_language(language)
        SUPPORTED_LANGUAGES.include?(language.to_s) ? language.to_s : 'en'
      end

      def build_system_message(type, language)
        case type
        when :evaluation
          if language == 'ja'
            <<~MSG.strip
              あなたは厳格な面接評価者です。候補者の回答を客観的に評価してください。
              絶対にJSON形式のみで回答してください。会話や説明は一切禁止です。
              質問への追加質問も禁止です。指定されたJSONスキーマに厳密に従ってください。
            MSG
          else
            <<~MSG.strip
              You are a strict interview evaluator. Evaluate the candidate's response objectively.
              You MUST respond with valid JSON only. No conversation, no explanations outside JSON.
              Do NOT ask follow-up questions. Follow the specified JSON schema exactly.
            MSG
          end
        when :summary
          if language == 'ja'
            <<~MSG.strip
              あなたは厳格な面接サマリー生成者です。面接結果を構造化して要約してください。
              絶対にJSON形式のみで回答してください。会話や説明は一切禁止です。
              指定されたJSONスキーマに厳密に従ってください。
            MSG
          else
            <<~MSG.strip
              You are a strict interview summarizer. Produce structured summaries of interview results.
              You MUST respond with valid JSON only. No conversation, no explanations outside JSON.
              Follow the specified JSON schema exactly.
            MSG
          end
        when :question_suggestions
          if language == 'ja'
            <<~MSG.strip
              あなたは採用企業の一次面接を設計する専門家です。
              提案する質問は、企業が求職者（応募者）に聞く面接質問のみです。
              すでにその職に就いている人への業務確認・人事評価・同僚ヒアリングの質問は禁止です。
              絶対にJSON形式のみで回答してください。会話や説明は一切禁止です。
            MSG
          else
            <<~MSG.strip
              You are an expert designing first-round hiring interviews for employers.
              Suggest ONLY questions that a company asks job applicants (candidates).
              Do NOT suggest questions that assume the person already holds the role (performance review or on-the-job checks).
              You MUST respond with valid JSON only. No conversation outside JSON.
            MSG
          end
        when :job_posting_extraction
          if language == 'ja'
            <<~MSG.strip
              あなたは採用向けの求人情報整理アシスタントです。
              与えられた求人ページ本文から、候補者向けの基本情報とFAQ候補を抽出してください。
              書いていない内容は推測で埋めず、空文字にしてください。
              絶対にJSON形式のみで回答してください。会話や説明は一切禁止です。
            MSG
          else
            <<~MSG.strip
              You extract structured job posting facts and FAQ candidates for job applicants.
              Do not invent facts that are not in the source text; use empty strings instead.
              Respond with valid JSON only.
            MSG
          end
        end
      end

      def build_open_evaluation(question_text, user_answer, language)
        if language == 'ja'
          <<~PROMPT.strip
            以下の面接質問と候補者の回答を評価してください。

            【面接質問】
            "#{sanitize(question_text)}"

            【候補者の回答】
            "#{sanitize(user_answer)}"

            【評価基準】
            1. relevance_score (0-100): 回答が質問に適切に対応しているか
            2. correctness_score (0-100): 情報が正確か
            3. clarity_score (0-100): 回答が明確で構造化されているか

            【出力ルール】
            - 会話禁止
            - 追加質問禁止
            - JSON出力のみ
            - スコアは必ず0-100の整数
            - 完全に無関係な回答は全スコア0

            以下のJSON形式のみで出力してください:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<簡潔な評価理由>"}
          PROMPT
        else
          <<~PROMPT.strip
            Evaluate the following interview question and candidate's answer.

            INTERVIEW QUESTION:
            "#{sanitize(question_text)}"

            CANDIDATE'S ANSWER:
            "#{sanitize(user_answer)}"

            EVALUATION CRITERIA:
            1. relevance_score (0-100): Does the answer address the question?
            2. correctness_score (0-100): Is the information accurate?
            3. clarity_score (0-100): Is the answer clear and well-structured?

            OUTPUT RULES:
            - No conversation
            - No follow-up questions
            - JSON output ONLY
            - All scores must be integers 0-100
            - If answer is completely irrelevant, set all scores to 0

            Return ONLY this JSON format:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<brief evaluation>"}
          PROMPT
        end
      end

      def build_choice_evaluation(question_text, user_answer, language)
        if language == 'ja'
          <<~PROMPT.strip
            以下の選択式面接質問に対する候補者の選択を評価してください。

            【質問】
            "#{sanitize(question_text)}"

            【候補者の選択】
            "#{sanitize(user_answer)}"

            以下のJSON形式のみで出力してください:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<簡潔な評価理由>"}
          PROMPT
        else
          <<~PROMPT.strip
            Evaluate the candidate's selection for the following multiple-choice interview question.

            QUESTION:
            "#{sanitize(question_text)}"

            CANDIDATE'S SELECTION:
            "#{sanitize(user_answer)}"

            Return ONLY this JSON format:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<brief evaluation>"}
          PROMPT
        end
      end

      def build_summary_message(responses_data, language)
        raise ArgumentError, "responses_data must not be empty" if responses_data.blank?

        serialized = responses_data.map do |r|
          { question: r[:question], answer: r[:answer], score: r[:score] }
        end

        if language == 'ja'
          <<~PROMPT.strip
            以下の面接回答データを要約してください。

            【回答データ】
            #{serialized.to_json}

            【出力ルール】
            - 会話禁止
            - JSON出力のみ
            - 要約は5文以内
            - strengthsとweaknessesは各3項目以内

            以下のJSON形式のみで出力してください:
            {"summary": "<要約>", "strengths": ["<強み1>", "<強み2>"], "weaknesses": ["<弱み1>", "<弱み2>"], "recommendation": "<採用推奨/不推奨/再検討>"}
          PROMPT
        else
          <<~PROMPT.strip
            Summarize the following interview response data.

            RESPONSES:
            #{serialized.to_json}

            OUTPUT RULES:
            - No conversation
            - JSON output ONLY
            - Summary under 5 sentences
            - Max 3 items each for strengths and weaknesses

            Return ONLY this JSON format:
            {"summary": "<summary>", "strengths": ["<strength1>", "<strength2>"], "weaknesses": ["<weakness1>", "<weakness2>"], "recommendation": "<hire/no hire/review>"}
          PROMPT
        end
      end

      def build_question_suggestions_message(industry:, job_title:, language:, count:, situation_title:)
        title = situation_title.to_s.presence || job_title
        if language == 'ja'
          <<~PROMPT.strip
            次の採用面接向けに、求職者（応募者）へ聞く質問を#{count}問提案してください。
            AI面接官が候補者に口頭で尋ねる一文として自然な日本語にしてください。

            【業種】
            #{sanitize(industry)}

            【募集職種】
            #{sanitize(job_title)}

            【シナリオ名】
            #{sanitize(title)}

            ルール:
            - 話し手は企業の面接官、聞き手は求職者（まだ採用されていない応募者）
            - 「現在その業務をどう行っているか」「業務でどんな工夫をしているか」など、在職・現職前提の質問は禁止
            - 「〜していますか？」のような現在進行の業務確認ではなく、経験・考え方・意欲・適性を聞く
            - 未経験でも答えられる質問と、関連経験がある人向けの行動面接（具体経験）を混ぜる
            - 職種固有の実務理解は「この仕事で大切だと思うこと」「もし任されたらどう進めるか」など応募者視点で聞く
            - 抽象的すぎる質問や差別につながりうる質問は避ける
            - question_type は原則 "open"
            - 最初の2問は required: true、残りは false を基本とする
            - category は短い日本語ラベル（例: 経歴, チームワーク, 専門性, 意欲）

            次のJSONのみを返すこと:
            {"questions":[{"question_text":"...","question_type":"open","required":true,"category":"...","reason":"なぜこの質問か1文"}]}
          PROMPT
        else
          <<~PROMPT.strip
            Suggest #{count} interview questions that a company asks job applicants for this hiring scenario.
            Write them as natural spoken questions an AI interviewer would ask a candidate.

            INDUSTRY:
            #{sanitize(industry)}

            ROLE:
            #{sanitize(job_title)}

            SCENARIO TITLE:
            #{sanitize(title)}

            Rules:
            - Speaker is the employer interviewer; listener is a job applicant (not yet hired)
            - Do NOT assume the candidate already works in this role (no on-the-job / performance-review questions)
            - Avoid present-tense "how do you currently do this job?" framing; ask about experience, judgment, motivation, and fit
            - Mix questions answerable by less experienced applicants with behavioral questions for related experience
            - For role-specific checks, use applicant framing such as "what would matter in this job" or "how would you approach..."
            - Avoid vague or discriminatory questions
            - question_type should be "open"
            - First two questions required:true, others false
            - category is a short label

            Return ONLY this JSON:
            {"questions":[{"question_text":"...","question_type":"open","required":true,"category":"...","reason":"one sentence why"}]}
          PROMPT
        end
      end

      def build_job_posting_extraction_message(source_text:, language:)
        body = sanitize_long(source_text, limit: 15_000)
        if language == 'ja'
          <<~PROMPT.strip
            次の求人ページ／求人票の本文から、候補者が確認すべき基本情報とFAQ候補を抽出してください。

            【本文】
            #{body}

            ルール:
            - 本文にない情報は空文字にする（推測しない）
            - job_summary は候補者向けに2〜5文で要約
            - employment_type は正社員・契約社員・業務委託・インターン等があればそのまま
            - location / salary_text は原文に近い短い文言
            - requirements_text は必須・歓迎条件の要点
            - selection_flow は選考ステップがあれば要約
            - faqs は候補者が迷いやすい点を最大5件（勤務地、リモート、給与、休日、選考など）。根拠のないFAQは作らない

            次のJSONのみを返すこと:
            {"job_title":"","industry":"","employment_type":"","location":"","salary_text":"","job_summary":"","requirements_text":"","selection_flow":"","faqs":[{"question":"...","answer":"...","category":"..."}]}
          PROMPT
        else
          <<~PROMPT.strip
            Extract structured job facts and up to 5 FAQ candidates from this posting text.

            SOURCE:
            #{body}

            Rules:
            - Use empty strings when the source does not contain the fact
            - job_summary should be 2-5 sentences for applicants
            - Do not invent FAQs without support in the source

            Return ONLY this JSON:
            {"job_title":"","industry":"","employment_type":"","location":"","salary_text":"","job_summary":"","requirements_text":"","selection_flow":"","faqs":[{"question":"...","answer":"...","category":"..."}]}
          PROMPT
        end
      end

      # ユーザー入力のサニタイズ（プロンプトインジェクション対策）
      # delimiter方式でユーザー入力を囲み、プロンプトとの境界を明確にする
      def sanitize(text)
        sanitize_long(text, limit: 2000)
      end

      def sanitize_long(text, limit: 2000)
        return '' if text.nil?

        sanitized = text.to_s
                        .gsub(/```/, '\'\'\'')
                        .strip
                        .truncate(limit)

        "---BEGIN USER INPUT---\n#{sanitized}\n---END USER INPUT---"
      end
    end
  end
end
