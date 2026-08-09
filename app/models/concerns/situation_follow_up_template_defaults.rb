# frozen_string_literal: true

module SituationFollowUpTemplateDefaults
  extend ActiveSupport::Concern

  DEFAULT_TEMPLATES = [
    {
      kind: "incomplete",
      delay_days: 1,
      subject: "【リマインド】「{{situation_title}}」の面接がまだ完了していません",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        {{company}} 採用担当です。
        「{{situation_title}}」のAI面接がまだ完了していないようです。

        下記リンクから続き（または再開）が可能です。お早めのご受験をお願いいたします。

        {{invite_url}}
      BODY
      include_next_step_link: false
    },
    {
      kind: "incomplete",
      delay_days: 3,
      subject: "【最終リマインド】「{{situation_title}}」面接受験のお願い",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        {{company}} 採用担当です。
        「{{situation_title}}」のAI面接について、改めてご案内いたします。

        ご都合の良いタイミングで、下記よりご受験ください。

        {{invite_url}}
      BODY
      include_next_step_link: false
    },
    {
      kind: "completed",
      delay_days: 0,
      subject: "「{{situation_title}}」ご受験ありがとうございました",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        {{company}} 採用担当です。
        「{{situation_title}}」のAI面接にご受験いただき、誠にありがとうございました。

        選考結果や次のステップについては、追ってご連絡いたします。
        ご不明点がございましたら、本メールへご返信ください。
      BODY
      include_next_step_link: true
    },
    {
      kind: "completed",
      delay_days: 3,
      subject: "「{{situation_title}}」選考の次のご案内",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        {{company}} 採用担当です。
        先日は「{{situation_title}}」の面接にご参加いただきありがとうございました。

        選考の進捗に合わせて、次のステップをご案内できる場合がございます。
        下記リンクから詳細をご確認ください。
      BODY
      include_next_step_link: true
    },
    {
      kind: "completed",
      delay_days: 7,
      subject: "選考状況のご確認 — {{situation_title}}",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        {{company}} 採用担当です。
        「{{situation_title}}」の選考から少しお時間が経ちました。

        状況のご確認や追加のご質問がございましたら、お気軽にご連絡ください。
      BODY
      include_next_step_link: true
    }
  ].freeze

  def ensure_follow_up_templates!
    return if interview_follow_up_templates.exists?

    DEFAULT_TEMPLATES.each_with_index do |attrs, idx|
      interview_follow_up_templates.create!(
        sequence: idx + 1,
        kind: attrs[:kind],
        enabled: true,
        delay_days: attrs[:delay_days],
        subject: attrs[:subject],
        body: attrs[:body],
        include_next_step_link: attrs[:include_next_step_link]
      )
    end
  end
end
