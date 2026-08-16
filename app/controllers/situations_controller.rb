class SituationsController < Dashboard::BaseController
  before_action :set_situation, only: [
    :show, :edit, :update, :destroy, :regenerate_invite_token,
    :suggest_questions, :apply_suggested_questions,
    :update_candidate_registration, :update_follow_up_settings,
    :upload_recruitment_material, :remove_recruitment_material,
    :update_job_info, :import_job_info
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
    @situation = build_new_situation
    load_clients_for_admin
  end

  def create
    @situation = build_new_situation(situation_params)
    if @situation.save
      redirect_to @situation, notice: t("recrivo.dashboard.flash.situation_created")
    else
      load_clients_for_admin
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @situation.update(situation_params)
      redirect_to @situation, notice: t("recrivo.dashboard.flash.situation_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @situation.destroy
    redirect_to situations_path, notice: t("recrivo.dashboard.flash.situation_deleted")
  end

  def regenerate_invite_token
    @situation.regenerate_invite_token!
    redirect_to @situation, notice: t("recrivo.dashboard.flash.invite_regenerated")
  end

  def update_candidate_registration
    @situation.skip_candidate_registration = ActiveModel::Type::Boolean.new.cast(params.dig(:situation, :skip_candidate_registration))
    @situation.assign_candidate_info_fields!(params.dig(:situation, :candidate_info_fields) || {})
    if @situation.save
      redirect_to @situation, notice: t("recrivo.dashboard.flash.registration_updated")
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

    redirect_to @situation, notice: t("recrivo.dashboard.flash.follow_updated")
  end

  def upload_recruitment_material
    file = params[:recruitment_material]
    unless file
      return redirect_to @situation, alert: t("recrivo.dashboard.flash.no_file")
    end

    @situation.recruitment_material.attach(file)
    redirect_to @situation, notice: t("recrivo.dashboard.flash.material_uploaded")
  end

  def remove_recruitment_material
    @situation.recruitment_material.purge if @situation.recruitment_material.attached?
    redirect_to @situation, notice: t("recrivo.dashboard.flash.material_removed")
  end

  def update_job_info
    if @situation.update(job_info_params)
      redirect_to @situation, notice: t("recrivo.dashboard.flash.job_info_saved")
    else
      redirect_to @situation, alert: @situation.errors.full_messages.join(", ")
    end
  end

  def import_job_info
    result = SituationJobInfo::ImportService.call(
      situation: @situation,
      url: params[:job_source_url],
      text: params[:job_source_text],
      apply_faqs: ActiveModel::Type::Boolean.new.cast(params[:apply_faqs].nil? ? true : params[:apply_faqs])
    )

    if result.success?
      faq_note = result.faqs.any? ? t("recrivo.dashboard.flash.job_imported_faq", count: result.faqs.size) : ""
      fallback_note = result.source == "paste_fallback" ? t("recrivo.dashboard.flash.job_imported_fallback") : ""
      redirect_to @situation, notice: t("recrivo.dashboard.flash.job_imported", faq_note: faq_note, fallback_note: fallback_note)
    else
      redirect_to @situation, alert: result.error
    end
  end

  # POST /situations/:id/suggest_questions
  def suggest_questions
    industry = params[:industry].presence || @situation.industry
    job_title = params[:job_title].presence || @situation.job_title

    if industry.blank? || job_title.blank?
      return render json: {
        success: false,
        error: t("recrivo.dashboard.js.need_industry_job")
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
    fallback = InterviewEngine::LLMClient.new.fallback_suggestions(
      industry.to_s,
      job_title.to_s,
      @situation.language,
      (params[:count].presence || 5).to_i.clamp(3, 8)
    )
    render json: {
      success: true,
      industry: industry,
      job_title: job_title,
      questions: fallback["questions"],
      fallback: true
    }
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
      return redirect_to @situation, alert: t("recrivo.dashboard.flash.select_questions")
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
          category: item[:category].to_s.presence || t("recrivo.dashboard.js.general"),
          order: next_order,
          published: false
        )
        next_order += 1
        created += 1
      end
    end

    if created.zero?
      redirect_to @situation, alert: t("recrivo.dashboard.flash.no_valid_questions")
    else
      redirect_to @situation, notice: t("recrivo.dashboard.flash.questions_added", count: created)
    end
  rescue JSON::ParserError
    redirect_to @situation, alert: t("recrivo.dashboard.flash.questions_invalid")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @situation, alert: t("recrivo.dashboard.flash.questions_failed", message: e.record.errors.full_messages.join(", "))
  end

  private

  def set_situation
    @situation = situations_scope.find(params[:id])
  end

  def situation_params
    permitted = [
      :title, :description, :language, :archived,
      :industry, :job_title,
      :session_timeout_minutes, :allow_resume, :max_resume_count,
      :passing_score, :auto_reject_enabled, :reject_on_required_fail,
      :min_required_score, :max_consecutive_fails, :reject_notify_method,
      :judgment_mode, :candidate_result_visibility,
      :allow_text_answer, :allow_voice_answer, :record_camera,
      :enable_satisfaction_survey, :follow_up_next_step_url,
      :skip_candidate_registration
    ]
    permitted << :client_id if acting_as_admin?
    params.require(:situation).permit(*permitted)
  end

  def job_info_params
    params.require(:situation).permit(
      :job_summary, :employment_type, :location, :salary_text,
      :requirements_text, :selection_flow, :job_source_url
    )
  end

  def build_new_situation(attrs = nil)
    record =
      if client_signed_in?
        current_client.situations.new(language: "ja", record_camera: true)
      else
        Situation.new(language: "ja", record_camera: true)
      end
    record.assign_attributes(attrs) if attrs.present?
    record
  end

  def load_clients_for_admin
    return unless acting_as_admin?

    @clients = Client.order(:company, :email)
  end

  def ensure_client_can_create!
    return if client_signed_in? || admin_signed_in?

    redirect_to situations_path, alert: t("recrivo.dashboard.flash.login_to_create")
  end

  def ensure_service_quota!
    return unless client_signed_in?
    return if current_client.can_create_service?

    redirect_to situations_path, alert: current_client.service_limit_message
  end
end
