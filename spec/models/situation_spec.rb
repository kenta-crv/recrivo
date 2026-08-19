require 'rails_helper'

RSpec.describe Situation, type: :model do
  let(:client) { create(:client) }

  describe 'associations' do
    it { is_expected.to belong_to(:client) }
    it { is_expected.to have_many(:questions).dependent(:destroy) }
    it { is_expected.to have_many(:interviews).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }

    it do
      is_expected.to validate_numericality_of(:session_timeout_minutes)
        .is_greater_than(0)
        .is_less_than_or_equal_to(180)
    end

    it do
      is_expected.to validate_numericality_of(:max_resume_count)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(10)
    end

    it do
      is_expected.to validate_numericality_of(:passing_score)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(100)
    end

    it do
      is_expected.to validate_inclusion_of(:reject_notify_method)
        .in_array(%w[in_app email none])
    end
  end

  describe 'scopes' do
    it '.active returns non-archived situations' do
      active = create(:situation, client: client, archived: false)
      create(:situation, client: client, archived: true)

      expect(Situation.active).to eq([active])
    end
  end

  describe '#allow_resume?' do
    it 'returns true when allow_resume is true' do
      situation = build(:situation, allow_resume: true)
      expect(situation.allow_resume?).to be true
    end

    it 'returns false when allow_resume is false' do
      situation = build(:situation, :no_resume)
      expect(situation.allow_resume?).to be false
    end
  end

  describe 'answer modes' do
    it 'is invalid when both text and voice are disabled' do
      situation = build(:situation, allow_text_answer: false, allow_voice_answer: false)
      expect(situation).not_to be_valid
      expect(situation.errors[:base]).to include('テキスト回答または音声回答のどちらか一方は有効にしてください')
    end

    it 'is valid for voice-only' do
      expect(build(:situation, :voice_only)).to be_valid
    end

    it 'is valid for text-only' do
      expect(build(:situation, :text_only)).to be_valid
    end

    it 'maps answer_mode to the boolean flags' do
      situation = build(:situation)
      situation.answer_mode = 'text'
      expect(situation.allow_text_answer).to be true
      expect(situation.allow_voice_answer).to be false
      expect(situation.answer_mode).to eq('text')

      situation.answer_mode = 'voice'
      expect(situation.allow_text_answer).to be false
      expect(situation.allow_voice_answer).to be true
      expect(situation.answer_mode).to eq('voice')

      situation.answer_mode = 'both'
      expect(situation.allow_text_answer).to be true
      expect(situation.allow_voice_answer).to be true
      expect(situation.answer_mode).to eq('both')
    end

    it 'defaults to voice-only' do
      expect(build(:situation).answer_mode).to eq('voice')
    end
  end

  describe 'judgment fields' do
    it 'is invalid without judgment_mode' do
      situation = build(:situation, judgment_mode: nil)
      expect(situation).not_to be_valid
      expect(situation.errors[:judgment_mode]).to be_present
    end

    it 'is invalid without candidate_result_visibility' do
      situation = build(:situation, candidate_result_visibility: nil)
      expect(situation).not_to be_valid
      expect(situation.errors[:candidate_result_visibility]).to be_present
    end
  end

  describe '#auto_reject_enabled?' do
    it 'returns value of auto_reject_enabled' do
      situation = build(:situation, auto_reject_enabled: true)
      expect(situation.auto_reject_enabled?).to be true
    end
  end
end
