require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'PLAN_CATALOG' do
    it 'returns LP display plans in catalog order' do
      expect(Subscription.lp_display_plans.map(&:first)).to eq(%i[trial starter standard business enterprise])
    end

    it 'has expected trial limits' do
      config = Subscription.plan_config(:trial)
      expect(config[:price]).to eq(0)
      expect(config[:situation_limit]).to eq(3)
      expect(config[:monthly_interview_limit]).to eq(20)
      expect(config[:post_trial_plan]).to eq(:standard)
    end

    it 'has expected starter limits and price' do
      config = Subscription.plan_config(:starter)
      expect(config[:price]).to eq(29_800)
      expect(config[:situation_limit]).to eq(3)
      expect(config[:monthly_interview_limit]).to eq(100)
      expect(config[:voice_ai_interview]).to be true
    end

    it 'marks standard as popular (blue highlight on LP)' do
      config = Subscription.plan_config(:standard)
      expect(config[:popular]).to be true
      expect(config[:featured]).to be false
      expect(config[:follow_up_automation]).to be true
    end

    it 'has expected business limits and featured flag' do
      config = Subscription.plan_config(:business)
      expect(config[:price]).to eq(98_000)
      expect(config[:situation_limit]).to eq(30)
      expect(config[:monthly_interview_limit]).to eq(2_000)
      expect(config[:follow_up_automation]).to be true
      expect(config[:priority_support]).to be true
      expect(config[:featured]).to be true
    end

    it 'has unlimited interviews for enterprise' do
      config = Subscription.plan_config(:enterprise)
      expect(config[:situation_limit]).to be_nil
      expect(config[:monthly_interview_limit]).to be_nil
      expect(config[:price]).to eq(198_000)
    end

    it 'returns nil for blank plan type' do
      expect(Subscription.plan_config(nil)).to be_nil
      expect(Subscription.plan_config("")).to be_nil
    end
  end

  describe '.format_feature_value' do
    it 'formats numeric limits' do
      expect(Subscription.format_feature_value(:trial, :situation_limit)).to eq('3')
      expect(Subscription.format_feature_value(:enterprise, :monthly_interview_limit)).to eq('無制限')
    end

    it 'shows checkmark for included boolean features' do
      expect(Subscription.format_feature_value(:business, :follow_up_automation)).to eq('✔︎')
    end

    it 'shows cross for excluded boolean features' do
      expect(Subscription.format_feature_value(:trial, :priority_support)).to eq('✕')
    end
  end

  describe 'client without subscription' do
    let(:client) { create(:client, email: "no-sub@example.com") }

    it 'falls back to trial plan config' do
      expect(client.current_plan_config[:situation_limit]).to eq(3)
    end
  end
end
