class SituationsController < Dashboard::BaseController
  before_action :set_situation, only: [
    :show, :edit, :update, :destroy, :regenerate_invite_token,
    :suggest_questions, :apply_suggested_questions,
    :update_candidate_registration, :update_follow_up_settings,
    :upload_recruitment_material, :remove_recruitment_material
  ]
  before_action :ensure_client_can_create!, only: [:new, :create]
  before_action :ensure_service_quota!, only: [:new, :create]

  def index
    @situations = situations_scope.includes(:client, :questions).order(updated_at: :desc)
  end

  def show
    @questions = @situation.questions.order(:order)
    @situation.ensure_follow_up_templates!
    @follow_up_templates = @situation.interview_follow_up_templates.ordered
    @faqs = @situation.situation_faqs.ordered
    @analytics = InterviewEngine::AnalyticsSummaryService.call(situation_ids: [@situation.id])
  end

  def new
    @situation = current_client.situations.new(language: "ja")
  end

  def create
    @situation = current_client.situations.new(situation_params)
    if @situation.save
      redirect_to @situation, notice: "面接シナリオを作成しました。業種・職種から質問をAI提案できます。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @situation.update(situation_params)
      redirect_to @situation, notice: "面接シナリオを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @situation.destroy
    redirect_to situations_path, notice: "面接シナリオを削除しました。"
  end

  def regenerate_invite_token
    @situation.regenerate_invite_token!
    redirect_to @situation, notice: "招待リンクを再発行しました。"
  end

  def update_candidate_registration
    @situation.skip_candidate_registration = ActiveModel::Type::Boolean.new.cast(params.dig(:situation, :skip_candidate_registration))
    @situation.assign_candidate_info_fields!(params.dig(:situation, :candidate_info_fields) || {})
    if @situation.save
      redirect_to @situation, notice: "受験者登録項目を更新しました。"
    else
      redirect_to @situation, alert: @situation.errors.full_messages.join(", ")
    end
  end

  def update_follow_up_settings
    @situation.ensure_follow_up_templates!
    @situation.update(follow_up_next_step_url: params.dig(:situation, :follow_up_next_step_url))

    templates_params = params[:templates]
    templates_hash =
      if templates_params.respond_to?(:to_unsafe_h)
        templates_params.to_unsafe_h
      elsif templates_params.is_a?(Hash)
        templates_params
      else
        {}
      end

    templates_hash.each do |id, attrs|
      template = @situation.interview_follow_up_templates.find_by(id: id)
      next unless template

      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      template.update(
        enabled: ActiveModel::Type::Boolean.new.cast(attrs["enabled"] || attrs[:enabled]),
        delay_days: attrs["delay_days"] || attrs[:delay_days],
        subject: attrs["subject"] || attrs[:subject],
        body: attrs["body"] || attrs[:body],
        include_next_step_link: ActiveModel::Type::Boolean.new.cast(attrs["include_next_step_link"] || attrs[:include_next_step_link])
      )
    end

    redirect_to @situation, notice: "フォロー設定を更新しました。"
  end

  def upload_recruitment_material
    file = params[:recruitment_material]
    unless file
      return redirect_to @situation, alert: "ファイルを選択してください。"
    end

    @situation.recruitment_material.attach(file)
    redirect_to @situation, notice: "募集資料をアップロードしました。"
  end

  def remove_recruitment_material
    @situation.recruitment_material.purge if @situation.recruitment_material.attached?
    redirect_to @situation, notice: "募集資料を削除しました。"
  end

  # POST /situations/:id/suggest_questions
  def suggest_questions
    industry = params[:industry].presence || @situation.industry
    job_title = params[:job_title].presence || @situation.job_title

    if industry.blank? || job_title.blank?
      return render json: {
        success: false,
        error: "業種と募集職種を入力してください。"
      }, status: :unprocessable_entity
    end

    @situation.update(industry: industry, job_title: job_title) if params[:persist].to_s == "1"

    count = (params[:count].presence || 5).to_i.clamp(3, 8)
    result = InterviewEngine::LLMClient.new.suggest_interview_questions(
      industry: industry,
      job_title: job_title,
      language: @situation.language,
      count: count,
      situation_title: @situation.title
    )

    render json: {
      success: true,
      industry: industry,
      job_title: job_title,
      questions: result["questions"]
    }
  rescue StandardError => e
    Rails.logger.error("suggest_questions failed: #{e.class}: #{e.message}")
    render json: { success: false, error: "質問の提案に失敗しました。しばらくして再試行してください。" }, status: :internal_server_error
  end

  # POST /situations/:id/apply_suggested_questions
  def apply_suggested_questions
    raw = params[:questions]
    items = if raw.is_a?(String)
              JSON.parse(raw)
            else
              Array(raw)
            end

    if items.blank?
      return redirect_to @situation, alert: "追加する質問を選択してください。"
    end

    created = 0
    next_order = (@situation.questions.maximum(:order) || 0) + 1

    ActiveRecord::Base.transaction do
      items.each do |item|
        item = item.to_unsafe_h if item.respond_to?(:to_unsafe_h)
        item = item.with_indifferent_access if item.is_a?(Hash)
        text = item[:question_text].to_s.strip
        next if text.blank?

        @situation.questions.create!(
          question_text: text,
          question_type: "open",
          required: ActiveModel::Type::Boolean.new.cast(item[:required]),
          category: item[:category].to_s.presence || "一般",
          order: next_order,
          published: false
        )
        next_order += 1
        created += 1
      end
    end

    if created.zero?
      redirect_to @situation, alert: "有効な質問がありませんでした。"
    else
      redirect_to @situation, notice: "#{created}問の質問を下書き（非公開）で追加しました。公開すると面接に出ます。"
    end
  rescue JSON::ParserError
    redirect_to @situation, alert: "質問データの形式が不正です。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @situation, alert: "質問の追加に失敗しました: #{e.record.errors.full_messages.join(', ')}"
  end

  private

  def set_situation
    @situation = situations_scope.find(params[:id])
  end

  def situation_params
    params.require(:situation).permit(
      :title, :description, :language, :archived,
      :industry, :job_title,
      :session_timeout_minutes, :allow_resume, :max_resume_count,
      :passing_score, :auto_reject_enabled, :reject_on_required_fail,
      :min_required_score, :max_consecutive_fails, :reject_notify_method,
      :judgment_mode, :candidate_result_visibility,
      :allow_text_answer, :allow_voice_answer, :record_camera,
      :enable_satisfaction_survey, :follow_up_next_step_url,
      :skip_candidate_registration
    )
  end

  def ensure_client_can_create!
    return if client_signed_in?

    redirect_to situations_path, alert: "シナリオの新規作成は企業アカウントで行ってください。"
  end

  def ensure_service_quota!
    return unless client_signed_in?
    return if current_client.can_create_service?

    redirect_to situations_path, alert: current_client.service_limit_message
  end
end
