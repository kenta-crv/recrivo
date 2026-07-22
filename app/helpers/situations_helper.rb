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
end
