module QuestionsHelper
  def question_open_answer_hint(situation)
    key =
      case situation.answer_mode
      when "voice" then "type_hint_voice"
      when "text" then "type_hint_text"
      else "type_hint_both"
      end
    I18n.t("recrivo.dashboard.questions.#{key}")
  end

  def question_mcq_hint
    I18n.t("recrivo.dashboard.questions.type_hint_mcq")
  end

  def question_type_hint(situation, question)
    if %w[mcq choice multiple_choice].include?(question.question_type.to_s)
      question_mcq_hint
    else
      question_open_answer_hint(situation)
    end
  end

  def default_choice_placeholders
    [
      I18n.t("recrivo.dashboard.questions.choice_ph"),
      I18n.t("recrivo.dashboard.questions.choice_ph_2"),
      I18n.t("recrivo.dashboard.questions.choice_ph_3")
    ]
  end
end
