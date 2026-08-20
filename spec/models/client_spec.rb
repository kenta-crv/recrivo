require 'rails_helper'

RSpec.describe Client, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:situations) }
  end

  describe 'validations' do
    it 'requires email' do
      client = build(:client, email: '')
      expect(client).not_to be_valid
      expect(client.errors[:email]).to be_present
    end

    it 'requires unique email' do
      create(:client, email: 'client@example.com')
      client = build(:client, email: 'client@example.com')
      expect(client).not_to be_valid
      expect(client.errors[:email]).to be_present
    end

    it 'requires valid email format' do
      client = build(:client, email: 'not-an-email')
      expect(client).not_to be_valid
    end

    it 'requires password with minimum length' do
      client = build(:client, password: 'short')
      expect(client).not_to be_valid
      expect(client.errors[:password]).to be_present
    end

    it 'creates with valid attributes' do
      client = build(:client)
      expect(client).to be_valid
    end
  end

  describe 'Devise modules' do
    it 'includes expected modules' do
      expected_modules = [:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable]
      expected_modules.each do |mod|
        expect(Client.devise_modules).to include(mod)
      end
    end
  end

  describe 'situations association' do
    it 'can have multiple situations' do
      client = create(:client)
      situation1 = create(:situation, client: client, title: 'シナリオ1')
      situation2 = create(:situation, client: client, title: 'シナリオ2')

      expect(client.situations).to include(situation1, situation2)
      expect(client.situations.count).to eq(2)
    end
  end
end

RSpec.describe "Yahoo Ads trial conversion", type: :request do
  it "新規登録でYAds CVフラグを立てる" do
    email = "trial-cv-#{SecureRandom.hex(4)}@example.com"
    post client_registration_path, params: {
      client: {
        email: email,
        password: "password123",
        password_confirmation: "password123"
      }
    }

    expect(response).to redirect_to(dashboard_index_path)
    expect(session[:yahoo_ads_trial_cv]).to eq(true)
    expect(ApplicationController.helpers.yahoo_ads_conversion_tags).to include("OS76L09XX08810RLPU1366130")
    expect(ApplicationController.helpers.yahoo_ads_conversion_tags).to include("yjad_conversion")
  end
end
