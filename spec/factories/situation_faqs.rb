# frozen_string_literal: true

FactoryBot.define do
  factory :situation_faq do
    association :situation
    sequence(:question) { |n| "FAQ質問 #{n}" }
    sequence(:answer) { |n| "FAQ回答 #{n}" }
    status { "approved" }
    sequence(:position) { |n| n }
  end
end
