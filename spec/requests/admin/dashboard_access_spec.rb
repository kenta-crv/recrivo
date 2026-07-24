require 'rails_helper'

RSpec.describe 'Admin dashboard access', type: :request do
  let(:admin) { create(:admin) }
  let(:client_record) { create(:client) }
  let!(:situation) { create(:situation, :with_questions, client: client_record) }
  let(:user) { create(:user) }
  let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }
  let!(:result) do
    interview.complete!
    create(:interview_result, interview: interview, final_status: :passed,
           results_data: { 'average_score' => 85, 'total_questions' => 3 })
  end

  before { sign_in admin }

  describe 'GET /situations' do
    it 'シナリオ一覧を表示できる' do
      get situations_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(situation.title)
    end
  end

  describe 'GET /situations/:id' do
    it 'シナリオ詳細を表示できる' do
      get situation_path(situation)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /situations/new' do
    it '新規作成は企業アカウント向けにリダイレクトする' do
      get new_situation_path
      expect(response).to redirect_to(situations_path)
      follow_redirect!
      expect(response.body).to include('企業アカウント')
    end
  end

  describe 'GET /dashboard/interview_results' do
    it '面接結果一覧を表示できる' do
      get dashboard_interview_results_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /dashboard/interview_results/:id' do
    it '面接結果詳細を表示できる' do
      get dashboard_interview_result_path(result)
      expect(response).to have_http_status(:ok)
    end
  end
end
