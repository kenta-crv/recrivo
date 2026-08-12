# frozen_string_literal: true

module SituationJobInfo
  class ImportService
    Result = Struct.new(:success?, :attrs, :faqs, :error, :source, keyword_init: true)

    def self.call(situation:, url: nil, text: nil, apply_faqs: true)
      new(situation: situation, url: url, text: text, apply_faqs: apply_faqs).call
    end

    def initialize(situation:, url: nil, text: nil, apply_faqs: true)
      @situation = situation
      @url = url.to_s.strip.presence
      @text = text.to_s.strip.presence
      @apply_faqs = apply_faqs
    end

    def call
      source_text, source = resolve_source_text
      extracted = InterviewEngine::LLMClient.new.extract_job_posting(source_text)
      attrs = build_attrs(extracted)
      faqs = normalize_faqs(extracted["faqs"] || extracted[:faqs])

      @situation.assign_attributes(attrs)
      @situation.save!

      created_faqs = []
      if @apply_faqs && faqs.any?
        created_faqs = create_faqs!(faqs)
      end

      Result.new(success?: true, attrs: attrs, faqs: created_faqs, error: nil, source: source)
    rescue PageFetcher::FetchError => e
      Result.new(success?: false, attrs: {}, faqs: [], error: e.message, source: "url")
    rescue InterviewEngine::LLMClient::LLMError, StandardError => e
      Rails.logger.error("[SituationJobInfo::ImportService] #{e.class}: #{e.message}")
      Result.new(success?: false, attrs: {}, faqs: [], error: "求人情報の解析に失敗しました。テキストを短くして再試行するか、手入力してください。", source: nil)
    end

    private

    def resolve_source_text
      if @url.present?
        begin
          return [PageFetcher.call(@url), "url"]
        rescue PageFetcher::FetchError
          raise if @text.blank?

          # URL失敗時は貼り付け本文へフォールバック
          return [@text, "paste_fallback"]
        end
      end

      raise PageFetcher::FetchError, "求人ページのURL、または求人テキストを入力してください。" if @text.blank?

      [@text, "paste"]
    end

    def build_attrs(extracted)
      h = extracted.is_a?(Hash) ? extracted.with_indifferent_access : {}
      {
        job_summary: h[:job_summary].to_s.strip.presence,
        employment_type: h[:employment_type].to_s.strip.presence,
        location: h[:location].to_s.strip.presence,
        salary_text: h[:salary_text].to_s.strip.presence,
        requirements_text: h[:requirements_text].to_s.strip.presence,
        selection_flow: h[:selection_flow].to_s.strip.presence,
        job_source_url: @url,
        job_title: h[:job_title].to_s.strip.presence || @situation.job_title,
        industry: h[:industry].to_s.strip.presence || @situation.industry
      }.compact
    end

    def normalize_faqs(raw)
      Array(raw).filter_map do |item|
        next unless item.is_a?(Hash)

        item = item.with_indifferent_access
        q = item[:question].to_s.strip
        a = item[:answer].to_s.strip
        next if q.blank? || a.blank?

        {
          question: q.truncate(200),
          answer: a.truncate(1000),
          category: item[:category].to_s.strip.presence || "求人情報"
        }
      end.first(8)
    end

    def create_faqs!(faqs)
      next_pos = (@situation.situation_faqs.maximum(:position) || 0) + 1
      existing_questions = @situation.situation_faqs.pluck(:question).map { |q| q.to_s.strip }
      created = []
      faqs.each do |faq|
        next if existing_questions.include?(faq[:question])

        created << @situation.situation_faqs.create!(
          question: faq[:question],
          answer: faq[:answer],
          category: faq[:category],
          status: "approved",
          position: next_pos
        )
        existing_questions << faq[:question]
        next_pos += 1
      end
      created
    end
  end
end
