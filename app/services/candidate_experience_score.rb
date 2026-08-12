# frozen_string_literal: true

# 候補者体験の充実度（公開初期の後追い整備メーター）
class CandidateExperienceScore
  WEIGHTS = {
    job_info: 35,
    faqs: 25,
    next_step_url: 20,
    materials: 10,
    published_questions: 10
  }.freeze

  ITEM_LABELS = {
    job_info: "求人基本情報",
    faqs: "FAQ",
    next_step_url: "次ステップ案内URL",
    materials: "採用資料",
    published_questions: "公開中の質問"
  }.freeze

  OPTIONAL_KEYS = %i[materials].freeze

  Gap = Struct.new(:key, :label, :situation_id, :situation_title, :optional, keyword_init: true)
  Result = Struct.new(
    :situation_id,
    :situation_title,
    :score,
    :max_score,
    :gaps,
    :breakdown,
    keyword_init: true
  )

  def self.for_situation(situation)
    new([situation]).call[:items].first
  end

  def self.for_situations(situations)
    new(situations).call
  end

  def initialize(situations)
    @situations = Array(situations)
  end

  def call
    items = @situations.map { |s| score_situation(s) }
    avg = if items.empty?
            nil
          else
            (items.sum { |i| i.score }.to_f / items.size).round
          end

    {
      average_score: avg,
      items: items,
      gaps: items.flat_map(&:gaps).reject(&:optional).first(12)
    }
  end

  private

  def score_situation(situation)
    breakdown = {}
    gaps = []

    check_item(situation, breakdown, gaps, :job_info) { situation.job_info_present? }
    check_item(situation, breakdown, gaps, :faqs) { situation.situation_faqs.approved.exists? }
    check_item(situation, breakdown, gaps, :next_step_url) { situation.follow_up_next_step_url.present? }
    check_item(situation, breakdown, gaps, :materials) { situation.recruitment_material.attached? }
    check_item(situation, breakdown, gaps, :published_questions) { situation.questions.published_only.exists? }

    score = breakdown.values.sum
    Result.new(
      situation_id: situation.id,
      situation_title: situation.title,
      score: score,
      max_score: WEIGHTS.values.sum,
      gaps: gaps,
      breakdown: breakdown
    )
  end

  def check_item(situation, breakdown, gaps, key)
    if yield
      breakdown[key] = WEIGHTS[key]
    else
      breakdown[key] = 0
      optional = OPTIONAL_KEYS.include?(key)
      gaps << Gap.new(
        key: key,
        label: "#{ITEM_LABELS[key]}が未設定",
        situation_id: situation.id,
        situation_title: situation.title,
        optional: optional
      )
    end
  end
end
