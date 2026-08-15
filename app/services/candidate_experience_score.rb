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

  JOB_INFO_FIELDS = %i[
    job_title
    job_summary
    employment_type
    location
    salary_text
    requirements_text
    selection_flow
  ].freeze

  FAQ_FULL_COUNT = 5
  PUBLISHED_QUESTIONS_FULL_COUNT = 3

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

    score_job_info(situation, breakdown, gaps)
    score_faqs(situation, breakdown, gaps)
    score_binary(situation, breakdown, gaps, :next_step_url) { situation.follow_up_next_step_url.present? }
    score_binary(situation, breakdown, gaps, :materials) { situation.recruitment_material.attached? }
    score_published_questions(situation, breakdown, gaps)

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

  def score_job_info(situation, breakdown, gaps)
    filled = JOB_INFO_FIELDS.count { |field| situation.public_send(field).present? }
    max = WEIGHTS[:job_info]
    breakdown[:job_info] = proportional_score(filled, JOB_INFO_FIELDS.size, max)
    add_gap_if_incomplete(gaps, situation, :job_info, breakdown[:job_info], max)
  end

  def score_faqs(situation, breakdown, gaps)
    count = situation.situation_faqs.approved.count
    max = WEIGHTS[:faqs]
    breakdown[:faqs] = proportional_score([count, FAQ_FULL_COUNT].min, FAQ_FULL_COUNT, max)
    add_gap_if_incomplete(gaps, situation, :faqs, breakdown[:faqs], max)
  end

  def score_published_questions(situation, breakdown, gaps)
    count = situation.questions.published_only.count
    max = WEIGHTS[:published_questions]
    breakdown[:published_questions] = proportional_score(
      [count, PUBLISHED_QUESTIONS_FULL_COUNT].min,
      PUBLISHED_QUESTIONS_FULL_COUNT,
      max
    )
    add_gap_if_incomplete(gaps, situation, :published_questions, breakdown[:published_questions], max)
  end

  def score_binary(situation, breakdown, gaps, key)
    if yield
      breakdown[key] = WEIGHTS[key]
    else
      breakdown[key] = 0
      add_gap(gaps, situation, key, partial: false)
    end
  end

  def proportional_score(actual, target, max)
    return 0 if target.zero? || actual.zero?

    (max * actual.to_f / target).round
  end

  def add_gap_if_incomplete(gaps, situation, key, score, max)
    return if score >= max

    add_gap(gaps, situation, key, partial: score.positive?)
  end

  def add_gap(gaps, situation, key, partial:)
    label = if partial
              "#{ITEM_LABELS[key]}が不足"
            else
              "#{ITEM_LABELS[key]}が未設定"
            end

    gaps << Gap.new(
      key: key,
      label: label,
      situation_id: situation.id,
      situation_title: situation.title,
      optional: OPTIONAL_KEYS.include?(key)
    )
  end
end
