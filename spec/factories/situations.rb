FactoryBot.define do
  factory :situation do
    association :client
    title { 'テスト面接シナリオ' }
    industry { 'IT・Web' }
    job_title { 'ソフトウェアエンジニア' }
    description { 'テスト用の面接シナリオです' }
    language { 'ja' }
    archived { false }
    session_timeout_minutes { 60 }
    allow_resume { true }
    max_resume_count { 3 }
    passing_score { 70 }
    auto_reject_enabled { false }
    reject_on_required_fail { true }
    min_required_score { 70 }
    max_consecutive_fails { 0 }
    reject_notify_method { 'in_app' }
    allow_text_answer { true }
    allow_voice_answer { true }
    record_camera { false }

    trait :with_questions do
      after(:create) do |situation|
        create_list(:question, 3, situation: situation)
      end
    end

    trait :no_resume do
      allow_resume { false }
    end

    trait :voice_only do
      allow_text_answer { false }
      allow_voice_answer { true }
    end

    trait :text_only do
      allow_text_answer { true }
      allow_voice_answer { false }
    end

    trait :with_camera do
      record_camera { true }
    end

    trait :short_timeout do
      session_timeout_minutes { 1 }
    end
  end
end
