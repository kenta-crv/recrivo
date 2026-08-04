class Subscription < ApplicationRecord
  belongs_to :client

  enum plan_type: { trial: "trial", starter: "starter", standard: "standard", business: "business", enterprise: "enterprise" }
  enum status: { active: "active", cancelled: "cancelled", expired: "expired" }

  validates :plan_type, presence: true
  validates :status, presence: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  TRIAL_DAYS = 10

  PLAN_CATALOG = {
    trial: {
      name: "トライアル",
      price: 0,
      situation_limit: 3,
      monthly_interview_limit: 20,
      voice_ai_interview: true,
      auto_scoring: true,
      guest_invite: true,
      result_dashboard: true,
      follow_up_automation: false,
      priority_support: false,
      description: "#{TRIAL_DAYS}日間。その後スタンダード移行",
      purchasable: false,
      public_on_lp: true,
      featured: false,
      stripe_price_env: nil,
      post_trial_plan: :standard,
      lp_cta: "無料で試す"
    },
    starter: {
      name: "スターター",
      price: 29_800,
      situation_limit: 3,
      monthly_interview_limit: 100,
      voice_ai_interview: true,
      auto_scoring: true,
      guest_invite: true,
      result_dashboard: true,
      follow_up_automation: false,
      priority_support: false,
      description: "小規模採用向け。シナリオ3・月100面接から始められます。",
      purchasable: true,
      public_on_lp: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_STARTER"
    },
    standard: {
      name: "スタンダード",
      price: 59_800,
      situation_limit: 10,
      monthly_interview_limit: 500,
      voice_ai_interview: true,
      auto_scoring: true,
      guest_invite: true,
      result_dashboard: true,
      follow_up_automation: true,
      priority_support: false,
      description: "成長中の採用チーム向け。シナリオ10・月500面接。",
      purchasable: true,
      public_on_lp: true,
      popular: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_STANDARD"
    },
    business: {
      name: "Business",
      price: 98_000,
      situation_limit: 30,
      monthly_interview_limit: 2_000,
      voice_ai_interview: true,
      auto_scoring: true,
      guest_invite: true,
      result_dashboard: true,
      follow_up_automation: true,
      priority_support: true,
      description: "本格運用向け。シナリオ30・月2,000面接。",
      purchasable: true,
      public_on_lp: true,
      featured: true,
      stripe_price_env: "STRIPE_PRICE_BUSINESS"
    },
    enterprise: {
      name: "エンタープライズ",
      price: 198_000,
      situation_limit: nil,
      monthly_interview_limit: nil,
      voice_ai_interview: true,
      auto_scoring: true,
      guest_invite: true,
      result_dashboard: true,
      follow_up_automation: true,
      priority_support: true,
      description: "大規模運用向け。シナリオ・面接数ともに無制限。",
      purchasable: true,
      public_on_lp: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_ENTERPRISE"
    }
  }.freeze

  LP_COMPARISON_FEATURES = [
    { key: :situation_limit, label: "面接シナリオ数" },
    { key: :monthly_interview_limit, label: "月間面接数" },
    { key: :voice_ai_interview, label: "AI音声面接" },
    { key: :auto_scoring, label: "合否・スコア自動評価" },
    { key: :guest_invite, label: "招待リンク（ログイン不要）" },
    { key: :result_dashboard, label: "結果ダッシュボード" },
    { key: :follow_up_automation, label: "フォロー自動化" },
    { key: :priority_support, label: "優先サポート" }
  ].freeze

  class << self
    def plan_config(plan_type)
      return nil if plan_type.blank?

      PLAN_CATALOG[plan_type.to_sym]
    end

    def public_plans
      PLAN_CATALOG.select { |_key, config| config[:public_on_lp] }
    end

    def lp_plans
      public_plans
    end

    def lp_display_plans
      PLAN_CATALOG.select { |_key, config| config[:public_on_lp] }.to_a
    end

    def purchasable_plans
      PLAN_CATALOG.select { |_key, config| config[:purchasable] }
    end

    def stripe_price_id_for(plan_type)
      env_key = plan_config(plan_type)&.dig(:stripe_price_env)
      return nil if env_key.blank?

      ENV[env_key].presence
    end

    def format_limit(value)
      value.nil? ? "無制限" : value.to_s
    end

    def format_feature_value(plan_type, feature_key)
      config = plan_config(plan_type)
      return "—" unless config

      case feature_key
      when :situation_limit, :monthly_interview_limit
        format_limit(config[feature_key])
      when :voice_ai_interview, :auto_scoring, :guest_invite, :result_dashboard, :follow_up_automation, :priority_support
        config[feature_key] ? "✔︎" : "✕"
      else
        config[feature_key].present? ? "✔︎" : "✕"
      end
    end
  end

  PLAN_NAMES = PLAN_CATALOG.transform_values { |c| c[:name] }.freeze
  PLAN_PRICES = PLAN_CATALOG.transform_values { |c| c[:price] }.freeze

  def plan_config
    self.class.plan_config(plan_type)
  end

  def plan_name
    plan_config&.dig(:name) || plan_type.to_s
  end

  def price
    plan_config&.dig(:price) || 0
  end

  def situation_limit
    plan_config&.dig(:situation_limit)
  end

  def monthly_interview_limit
    plan_config&.dig(:monthly_interview_limit)
  end

  def service_limit
    situation_limit
  end

  def trial?
    plan_type == "trial"
  end

  def trial_active?
    trial? && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_expired?
    trial? && trial_ends_at.present? && trial_ends_at <= Time.current
  end

  def expire_trial_and_upgrade!
    return unless trial?
    return if trial_ends_at.blank?
    return if trial_ends_at > Time.current
    return if status != "active"

    upgrade_plan = plan_config&.dig(:post_trial_plan) || :standard

    transaction do
      update!(status: :expired)
      client.subscriptions.where(status: :active).update_all(status: :cancelled)
      client.subscriptions.create!(plan_type: upgrade_plan, status: :active)
      client.update!(subscription_plan: upgrade_plan.to_s, subscription_status: "active")
    end
  end
end
