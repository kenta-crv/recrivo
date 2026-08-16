module SituationsHelper
  BASIC_INTERVIEW_QUESTIONS = [
    {
      question_text: "まず、簡単に自己紹介をお願いします。",
      category: "自己紹介",
      required: true,
      reason: "話し方と経歴の概要を把握します。"
    },
    {
      question_text: "今回の職種・募集に応募した理由を教えてください。",
      category: "志望動機",
      required: true,
      reason: "応募動機と理解度を確認します。"
    },
    {
      question_text: "ご自身の強みと、それを仕事でどう活かしてきたか教えてください。",
      category: "強み",
      required: true,
      reason: "自己理解と実績の具体性を見ます。"
    },
    {
      question_text: "改善したい点や苦手なことがあれば、どう向き合っているか教えてください。",
      category: "自己理解",
      required: false,
      reason: "課題認識と改善姿勢を確認します。"
    },
    {
      question_text: "これまでに直面した困難な状況と、それをどう乗り越えたか具体的に教えてください。",
      category: "課題解決",
      required: true,
      reason: "行動面接で対応力を確認します。"
    },
    {
      question_text: "チームで意見が分かれたとき、どのように話し合って進めた経験がありますか？",
      category: "チームワーク",
      required: false,
      reason: "協調性とコミュニケーションを見ます。"
    },
    {
      question_text: "複数の仕事が重なったとき、優先順位をどうつけて進めますか？",
      category: "働き方",
      required: false,
      reason: "判断基準と実務遂行力を確認します。"
    },
    {
      question_text: "お客様や周囲の人に対応するうえで、大切にしていることを教えてください。",
      category: "対人姿勢",
      required: false,
      reason: "サービス意識と丁寧さを確認します。"
    },
    {
      question_text: "これまでの経験のなかで、もっとも成長を感じた出来事を教えてください。",
      category: "成長",
      required: false,
      reason: "学習姿勢と振り返り力を見ます。"
    },
    {
      question_text: "もし採用された場合、最初の1か月で取り組みたいことを教えてください。",
      category: "意欲",
      required: false,
      reason: "入社後のイメージと主体性を確認します。"
    }
  ].freeze

  def basic_interview_questions
    BASIC_INTERVIEW_QUESTIONS
  end

  def question_type_label(type)
    case type.to_s
    when "open", "text"
      I18n.t("recrivo.dashboard.questions.type_open")
    when "mcq", "choice", "multiple_choice"
      I18n.t("recrivo.dashboard.questions.type_mcq")
    else
      type.to_s
    end
  end

  def situation_judgment_summary(situation)
    parts = []
    parts << if situation.manual_judgment?
               I18n.t("recrivo.dashboard.situations.judgment.manual")
             else
               I18n.t("recrivo.dashboard.situations.judgment.automatic")
             end
    parts << I18n.t("recrivo.dashboard.situations.judgment.passing", score: situation.passing_score)
    parts << if situation.hide_result_from_candidate?
               I18n.t("recrivo.dashboard.situations.judgment.hide_result")
             else
               I18n.t("recrivo.dashboard.situations.judgment.show_result")
             end
    modes = []
    modes << I18n.t("recrivo.dashboard.situations.form.text") if situation.allow_text_answer?
    modes << I18n.t("recrivo.dashboard.situations.form.voice") if situation.allow_voice_answer?
    parts << modes.join("/") if modes.any?
    parts << I18n.t("recrivo.dashboard.situations.judgment.auto_reject") if situation.auto_reject_enabled?
    parts.join(I18n.locale.to_s == "en" ? " · " : "・")
  end

  def job_info_field_labels
    {
      job_title: I18n.t("recrivo.dashboard.situations.job_title"),
      employment_type: I18n.t("recrivo.dashboard.situations.employment_type"),
      location: I18n.t("recrivo.dashboard.situations.location"),
      salary_text: I18n.t("recrivo.dashboard.situations.salary"),
      job_summary: I18n.t("recrivo.dashboard.situations.job_summary"),
      requirements_text: I18n.t("recrivo.dashboard.situations.requirements"),
      selection_flow: I18n.t("recrivo.dashboard.situations.selection_flow")
    }
  end

  def situation_section_param
    params[:section].to_s.presence
  end

  def situation_section_open?(*ids)
    current = situation_section_param
    return false if current.blank?

    ids.flatten.map(&:to_s).include?(current)
  end
end
