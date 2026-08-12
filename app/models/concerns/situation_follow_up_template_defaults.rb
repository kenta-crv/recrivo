# frozen_string_literal: true

module SituationFollowUpTemplateDefaults
  extend ActiveSupport::Concern

  DEFAULT_TEMPLATES = [
    {
      kind: "incomplete",
      delay_days: 1,
      subject: "【{{company}}】「{{situation_title}}」面接のご案内",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        お世話になっております。{{company}} 採用担当です。

        「{{situation_title}}」の面接につきまして、まだご対応が完了していないようです。
        ご都合の良いお時間に、下記よりお進みいただけますと幸いです。

        {{invite_url}}

        ご不明点がございましたら、本メールへご返信ください。
        どうぞよろしくお願いいたします。

        {{company}}
        採用担当
      BODY
      include_next_step_link: false
    },
    {
      kind: "incomplete",
      delay_days: 3,
      subject: "【{{company}}】「{{situation_title}}」面接の再案内",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        お世話になっております。{{company}} 採用担当です。

        先日ご案内いたしました「{{situation_title}}」の面接について、改めてご連絡いたします。
        ご多忙のところ恐れ入りますが、下記よりご対応いただけますと幸いです。

        {{invite_url}}

        何卒よろしくお願いいたします。

        {{company}}
        採用担当
      BODY
      include_next_step_link: false
    },
    {
      kind: "completed",
      delay_days: 0,
      subject: "【{{company}}】「{{situation_title}}」面接へのお礼",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        お世話になっております。{{company}} 採用担当です。

        このたびは「{{situation_title}}」の面接にご参加いただき、誠にありがとうございました。
        選考結果および今後の流れにつきましては、改めてご連絡いたします。

        ご不明点がございましたら、本メールへご返信ください。
        どうぞよろしくお願いいたします。

        {{company}}
        採用担当
      BODY
      include_next_step_link: true
    },
    {
      kind: "completed",
      delay_days: 3,
      subject: "【{{company}}】「{{situation_title}}」選考のご案内",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        お世話になっております。{{company}} 採用担当です。

        先日は「{{situation_title}}」の面接にご参加いただきありがとうございました。
        選考の進捗に応じて、次のステップをご案内できる場合がございます。

        詳細は追ってご連絡いたします。ご不明点がございましたら、お気軽にご連絡ください。

        {{company}}
        採用担当
      BODY
      include_next_step_link: true
    },
    {
      kind: "completed",
      delay_days: 7,
      subject: "【{{company}}】選考状況についてのご連絡",
      body: <<~BODY.strip,
        {{candidate_name}} 様

        お世話になっております。{{company}} 採用担当です。

        「{{situation_title}}」の選考についてご連絡いたします。
        状況のご確認やご質問がございましたら、本メールへご返信ください。

        引き続き、どうぞよろしくお願いいたします。

        {{company}}
        採用担当
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
        delay_days: attrs[:delay_days],
        subject: attrs[:subject],
        body: attrs[:body],
        enabled: true,
        include_next_step_link: attrs[:include_next_step_link]
      )
    end
  end
end
