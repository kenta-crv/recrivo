class QuestionsController < Dashboard::BaseController
  before_action :authenticate_client_only!
  before_action :set_situation
  before_action :set_question, only: [:edit, :update, :destroy, :toggle_publish]

  def index
    redirect_to situation_path(@situation)
  end

  def new
    @question = @situation.questions.new(
      question_type: "open",
      order: @situation.questions.count + 1,
      required: true,
      published: true
    )
  end

  def create
    @question = @situation.questions.new(question_params)
    if @question.save
      redirect_to situation_path(@situation), notice: "質問を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @question.update(question_params)
      redirect_to situation_path(@situation), notice: "質問を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @question.destroy
    redirect_to situation_path(@situation), notice: "質問を削除しました。"
  end

  def toggle_publish
    @question.update!(published: !@question.published?)
    label = @question.published? ? "公開" : "非公開"
    redirect_to situation_path(@situation), notice: "質問を#{label}にしました。"
  end

  private

  def set_situation
    @situation = current_client.situations.find(params[:situation_id])
  end

  def set_question
    @question = @situation.questions.find(params[:id])
  end

  def question_params
    permitted = params.require(:question).permit(
      :question_text, :question_type, :order,
      :required, :category, :published,
      :branch_enabled, :branch_type, :branch_source_order,
      :branch_value, :branch_action, :branch_default_action
    )
    attrs = permitted.to_h
    apply_choice_options!(attrs)
    apply_branching_rules!(attrs)
    attrs
  end

  def apply_choice_options!(attrs)
    type = attrs["question_type"].to_s
    if %w[mcq choice multiple_choice].include?(type)
      texts = Array(params.dig(:question, :choice_texts)).map { |t| t.to_s.strip }.reject(&:blank?)
      correct = params.dig(:question, :correct_choice).to_s.strip
      correct = nil unless texts.include?(correct)

      options = { "choices" => texts }
      options["correct"] = correct if correct.present?
      attrs["options"] = options
      attrs["question_type"] = "mcq"
    else
      attrs["options"] = nil
      attrs["question_type"] = "open" if type.blank? || type == "text"
    end
  end

  def apply_branching_rules!(attrs)
    enabled = ActiveModel::Type::Boolean.new.cast(attrs.delete("branch_enabled"))
    branch_type = attrs.delete("branch_type").to_s
    source_order = attrs.delete("branch_source_order")
    branch_value = attrs.delete("branch_value")
    branch_action = attrs.delete("branch_action").presence || "include"
    default_action = attrs.delete("branch_default_action").presence || "exclude"

    unless enabled
      attrs["branching_rules"] = nil
      return
    end

    condition = {
      "type" => branch_type.presence || "answered",
      "source_question_order" => source_order.to_i,
      "action" => branch_action
    }
    if %w[selected_option score_above score_below].include?(condition["type"])
      condition["value"] = branch_value
    end

    attrs["branching_rules"] = {
      "conditions" => [condition],
      "default_action" => default_action
    }
  end
end
