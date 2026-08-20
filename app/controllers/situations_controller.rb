class SituationsController < Dashboard::BaseController
  wrap_parameters false
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
    @suggested_questions = load_suggested_questions_for(@situation.id)
  end

  def new
    @situation = build_new_situation
    load_clients_for_admin
    assign_company_name_for_form
  end

  def create
    @situation = build_new_situation(situation_params)
    assign_company_name_for_form
    if company_name_missing_for_situation_owner?
      @situation.errors.add(:base, t("recrivo.dashboard.flash.company_required"))
      load_clients_for_admin
      render :new, status: :unprocessable_entity
    elsif @situation.save
      sync_company_to_situation_owner
      redirect_to @situation, notice: t("recrivo.dashboard.flash.situation_created")
    else
      load_clients_for_admin
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    assign_company_name_for_form
  end

  def update
    assign_company_name_for_form
    if company_name_missing_for_situation_owner?
      @situation.errors.add(:base, t("recrivo.dashboard.flash.company_required"))
      render :edit, status: :unprocessable_entity
    elsif @situation.update(situation_params)
      sync_company_to_situation_owner
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
    industry = suggest_param(:industry).presence || @situation.industry
    job_title = suggest_param(:job_title).presence || @situation.job_title

    if industry.blank? || job_title.blank?
      message = t("recrivo.dashboard.js.need_industry_job")
      if request.format.json?
        return render json: { success: false, error: message }, status: :unprocessable_entity
      end
      return redirect_to situation_path(@situation, anchor: "questions"), alert: message
    end

    persist = suggest_param(:persist).to_s == "1" || suggest_param(:persist).nil?
    @situation.update(industry: industry, job_title: job_title) if persist

    count = (suggest_param(:count).presence || 5).to_i.clamp(3, 8)
    questions = InterviewEngine::LLMClient.new.fallback_suggestions(
      industry.to_s,
      job_title.to_s,
      @situation.language,
      count
    )["questions"]

    store_suggested_questions_for(@situation.id, questions)

    if request.format.json?
      return render json: {
        success: true,
        industry: industry,
        job_title: job_title,
        questions: questions
      }
    end
    redirect_to situation_path(@situation, anchor: "questions"),
                notice: t("recrivo.dashboard.js.suggested", count: questions.size)
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
          required: true,
          category: item[:category].to_s.presence || t("recrivo.dashboard.js.general"),
          order: next_order,
          published: true
        )
        next_order += 1
        created += 1
      end
    end

    if created.zero?
      redirect_to @situation, alert: t("recrivo.dashboard.flash.no_valid_questions")
    else
      clear_suggested_questions_for(@situation.id)
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

  def suggest_param(key)
    params[key].presence || params.dig(:situation, key)
  end

  def suggested_questions_session
    store = session[:ai_suggested_questions]
    store.is_a?(Hash) ? store : {}
  end

  def load_suggested_questions_for(situation_id)
    store = suggested_questions_session
    return Array(store[situation_id.to_s]) if store.key?(situation_id.to_s)
    return Array(store[situation_id]) if store.key?(situation_id)

    # Backward compatibility: legacy global array from older versions.
    legacy = session[:ai_suggested_questions]
    legacy.is_a?(Array) ? legacy : []
  end

  def store_suggested_questions_for(situation_id, questions)
    store = suggested_questions_session
    store[situation_id.to_s] = Array(questions).map { |q| q.respond_to?(:to_h) ? q.to_h.stringify_keys : q }
    session[:ai_suggested_questions] = store
  end

  def clear_suggested_questions_for(situation_id)
    store = suggested_questions_session
    store.delete(situation_id.to_s)
    store.delete(situation_id)
    session[:ai_suggested_questions] = store
  end

  def situation_params
    permitted = [
      :title, :description, :language, :archived,
      :industry, :job_title,
      :session_timeout_minutes, :allow_resume, :max_resume_count,
      :passing_score, :auto_reject_enabled, :reject_on_required_fail,
      :min_required_score, :max_consecutive_fails, :reject_notify_method,
      :judgment_mode, :candidate_result_visibility,
      :answer_mode, :record_camera,
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
        current_client.situations.new(language: "ja", record_camera: true, allow_text_answer: false, allow_voice_answer: true)
      else
        Situation.new(language: "ja", record_camera: true, allow_text_answer: false, allow_voice_answer: true)
      end
    if attrs.present?
      record.assign_attributes(attrs)
    else
      record.judgment_mode = nil
      record.candidate_result_visibility = nil
    end
    record
  end

  def load_clients_for_admin
    return unless acting_as_admin?

    @clients = Client.order(:company, :email)
  end

  def assign_company_name_for_form
    @company_name = company_name_param.presence || situation_owner_client&.company.to_s
  end

  def company_name_param
    params.dig(:situation, :company).to_s.strip.presence
  end

  def situation_owner_client
    return current_client if client_signed_in?

    @situation&.client || Client.find_by(id: params.dig(:situation, :client_id))
  end

  def company_name_missing_for_situation_owner?
    company_name_param.blank?
  end

  def sync_company_to_situation_owner
    client = situation_owner_client
    return if client.blank?

    client.update_company_name(company_name_param)
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
