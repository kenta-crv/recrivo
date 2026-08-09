module SituationsHelper
  def question_type_label(type)
    {
      "open" => "自由回答",
      "mcq" => "選択式",
      "text" => "自由回答",
      "choice" => "選択式",
      "multiple_choice" => "選択式"
    }[type.to_s] || type.to_s
  end

  def situation_judgment_summary(situation)
    parts = []
    parts << (situation.manual_judgment? ? "面接官が判定" : "自動判定")
    parts << "合格#{situation.passing_score}点"
    parts << (situation.hide_result_from_candidate? ? "結果非表示" : "結果その場表示")
    modes = []
    modes << "テキスト" if situation.allow_text_answer?
    modes << "音声" if situation.allow_voice_answer?
    parts << modes.join("/") if modes.any?
    parts << "途中不合格あり" if situation.auto_reject_enabled?
    parts.join("・")
  end
end
