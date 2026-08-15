# frozen_string_literal: true

require "rails_helper"

RSpec.describe CandidateExperienceScore do
  let(:client) { create(:client) }
  let(:situation) do
    create(
      :situation,
      client: client,
      job_title: nil,
      job_summary: nil,
      employment_type: nil,
      location: nil,
      salary_text: nil,
      requirements_text: nil,
      selection_flow: nil,
      follow_up_next_step_url: nil
    )
  end

  describe ".for_situation" do
    it "公開中の質問のみのときは低スコアになる" do
      create_list(:question, 3, situation: situation, published: true)

      result = described_class.for_situation(situation)

      expect(result.score).to eq(10)
      expect(result.breakdown[:published_questions]).to eq(10)
    end

    it "FAQ1件と求人項目1件だけでは大幅に上がらない" do
      create_list(:question, 3, situation: situation, published: true)
      situation.update!(location: "東京都")
      create(:situation_faq, situation: situation, status: "approved")

      result = described_class.for_situation(situation)

      expect(result.score).to eq(20)
      expect(result.breakdown[:job_info]).to eq(5)
      expect(result.breakdown[:faqs]).to eq(5)
      expect(result.breakdown[:published_questions]).to eq(10)
    end

    it "各項目を十分に整えると満点になる" do
      create_list(:question, 3, situation: situation, published: true)
      situation.update!(
        job_title: "エンジニア",
        job_summary: "開発業務",
        employment_type: "正社員",
        location: "東京都",
        salary_text: "500万円〜",
        requirements_text: "Ruby経験",
        selection_flow: "書類→面接",
        follow_up_next_step_url: "https://example.com/next"
      )
      5.times do |i|
        create(
          :situation_faq,
          situation: situation,
          status: "approved",
          question: "質問#{i}",
          answer: "回答#{i}"
        )
      end

      result = described_class.for_situation(situation)

      expect(result.score).to eq(90)
      expect(result.gaps).to be_empty
    end
  end
end
