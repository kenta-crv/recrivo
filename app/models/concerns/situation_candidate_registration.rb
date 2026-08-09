# frozen_string_literal: true

module SituationCandidateRegistration
  extend ActiveSupport::Concern

  CANDIDATE_INFO_FIELD_MODES = %w[hidden optional required].freeze
  CANDIDATE_INFO_FIELDS = %w[name email tel address job_title company url].freeze

  DEFAULT_CANDIDATE_INFO_FIELDS = {
    "name" => "required",
    "email" => "required",
    "tel" => "required",
    "address" => "required",
    "job_title" => "hidden",
    "company" => "hidden",
    "url" => "hidden"
  }.freeze

  FIELD_LABELS = {
    "name" => "お名前",
    "email" => "メールアドレス",
    "tel" => "電話番号",
    "address" => "住所",
    "job_title" => "現職・希望職種",
    "company" => "現所属",
    "url" => "ポートフォリオURL"
  }.freeze

  def resolved_candidate_info_fields
    raw = candidate_info_fields.is_a?(Hash) ? candidate_info_fields.stringify_keys : {}
    DEFAULT_CANDIDATE_INFO_FIELDS.merge(raw.slice(*CANDIDATE_INFO_FIELDS)).tap do |fields|
      fields.each do |key, mode|
        fields[key] = CANDIDATE_INFO_FIELD_MODES.include?(mode.to_s) ? mode.to_s : "optional"
      end
    end
  end

  def candidate_info_field_mode(key)
    resolved_candidate_info_fields[key.to_s] || "hidden"
  end

  def visible_candidate_info_fields
    resolved_candidate_info_fields.reject { |_k, mode| mode == "hidden" }.keys
  end

  def required_candidate_info_fields
    resolved_candidate_info_fields.select { |_k, mode| mode == "required" }.keys
  end

  def candidate_registration_required?
    !skip_candidate_registration? && visible_candidate_info_fields.any?
  end

  def assign_candidate_info_fields!(raw_fields)
    incoming = raw_fields.is_a?(ActionController::Parameters) ? raw_fields.to_unsafe_h : raw_fields
    incoming = (incoming || {}).stringify_keys
    merged = resolved_candidate_info_fields.dup
    CANDIDATE_INFO_FIELDS.each do |key|
      mode = incoming[key].to_s
      next unless CANDIDATE_INFO_FIELD_MODES.include?(mode)

      merged[key] = mode
    end
    # email/name は最低でも optional（完全非表示は運用事故になりやすい）
    merged["name"] = "required" if merged["name"] == "hidden"
    merged["email"] = "required" if merged["email"] == "hidden"
    self.candidate_info_fields = merged
  end
end
