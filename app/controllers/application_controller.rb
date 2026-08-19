class ApplicationController < ActionController::Base
  include MetaTags::ControllerHelper

  layout :layout_for_request

  before_action :set_locale
  before_action :stash_omniauth_locale
  before_action :init_breadcrumbs
  before_action :set_active_storage_url_options
  helper_method :breadcrumbs, :current_locale, :locale_root_href, :href_for_locale,
                :available_ui_locales, :locale_switch_path_for, :acting_as_admin?
  before_action :check_trial_expiration

  def acting_as_admin?
    admin_signed_in? && !client_signed_in?
  end

  def check_trial_expiration
    return unless current_client.present?
    current_client.check_and_upgrade_expired_trial
  end

  def breadcrumbs
    @breadcrumbs
  end

  def add_breadcrumb(label, path = nil)
    @breadcrumbs << { label: label, path: path }
  end

  def current_locale
    I18n.locale
  end

  def available_ui_locales
    %i[ja en]
  end

  def locale_root_href
    if I18n.locale.to_s == "en"
      localized_root_path(locale: :en)
    else
      root_path
    end
  end

  # 公開ページは / <-> /en。認証・plans も同様。それ以外は locale 切替エンドポイントへ。
  def href_for_locale(target_locale)
    target = target_locale.to_s
    return locale_root_href if target.blank?

    path = request.path.to_s.sub(%r{\A/en(?=/|$)}, "")
    path = "/" if path.blank?

    if public_switchable_path?(path)
      target == "ja" ? path : (path == "/" ? "/en" : "/en#{path}")
    else
      locale_switch_path_for(target, return_to: request.fullpath)
    end
  end

  def locale_switch_path_for(target_locale, return_to: nil)
    switch_locale_path(locale: target_locale, return_to: return_to.presence || request.fullpath)
  end

  protected

  def set_locale
    locale = resolve_ui_locale
    I18n.locale = locale

    path = request.path.to_s.sub(%r{\A/en(?=/|$)}, "")
    path = "/" if path.blank?
    # 公開SEO用URLは表示localeを強制するが、ユーザーのUI希望(session/cookie)は消さない
    return if public_switchable_path?(path)

    persist_ui_locale!(locale)
  end

  def persist_ui_locale!(locale)
    value = locale.to_s
    return unless Client::LOCALES.include?(value)

    session[:ui_locale] = value
    cookies[:ui_locale] = {
      value: value,
      expires: 1.year,
      path: "/",
      same_site: :lax
    }
  end

  def auth_url_locale
    return "en" if params[:locale].to_s == "en"
    return "en" if request.path.to_s.match?(%r{\A/en(/|\z)})

    "ja"
  end

  # OAuth は /clients/auth/*（/en 外）へ飛ぶため、開始時点の UI locale を session に残す
  def stash_omniauth_locale
    return unless request.path.to_s.start_with?("/clients/auth/")
    return if request.path.to_s.include?("/callback")

    locale = params[:locale].presence.to_s
    locale = session[:omniauth_locale].to_s unless Client::LOCALES.include?(locale)
    locale = auth_url_locale unless Client::LOCALES.include?(locale)
    session[:omniauth_locale] = locale if Client::LOCALES.include?(locale)
  end

  def resolve_ui_locale
    requested = params[:locale].presence.to_s
    return requested.to_sym if Client::LOCALES.include?(requested)

    # /en なしの公開URLは明示的に日本語（session に en が残っていても上書き）
    path = request.path.to_s.sub(%r{\A/en(?=/|$)}, "")
    path = "/" if path.blank?
    return :ja if public_switchable_path?(path)

    if client_signed_in? && current_client.preferred_locale.present?
      return current_client.ui_locale
    end

    session_locale = session[:ui_locale].to_s
    return session_locale.to_sym if Client::LOCALES.include?(session_locale)

    cookie_locale = cookies[:ui_locale].to_s
    return cookie_locale.to_sym if Client::LOCALES.include?(cookie_locale)

    :ja
  end


  def public_switchable_path?(path)
    path == "/" ||
      path == "/plans" ||
      path.start_with?("/plans") ||
      path.start_with?("/clients/sign_in") ||
      path.start_with?("/clients/sign_up") ||
      path.start_with?("/clients/password") ||
      path.start_with?("/clients/auth") ||
      (path == "/clients" && !client_signed_in?)
  end

  # 127.0.0.1 で開いているのに ActiveStorage が localhost へリダイレクトすると音声再生が壊れる
  def set_active_storage_url_options
    return unless defined?(ActiveStorage::Current)

    # Rails 6.1 は host=、7+ は url_options=。誤検知で落ちないよう host を優先
    if ActiveStorage::Current.respond_to?(:host=)
      ActiveStorage::Current.host = request.base_url
    elsif ActiveStorage::Current.respond_to?(:url_options=)
      opts = { protocol: request.protocol, host: request.host }
      opts[:port] = request.port unless [80, 443].include?(request.port)
      ActiveStorage::Current.url_options = opts
    end
  end

  def reject_client_auth_while_admin!
    return unless admin_signed_in?

    redirect_to dashboard_root_path,
                alert: t("recrivo.auth.admin_session_blocks_client",
                         default: "管理者でログイン中です。企業アカウントの登録・ログインは、管理者をログアウトしてから行ってください。")
  end

  def after_sign_in_path_for(resource)
    case resource
    when Admin
      sign_out(:client) if client_signed_in?
      dashboard_root_path
    when Client
      dashboard_root_path
    else
      locale_root_href
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    locale_root_href
  end

  def layout_for_request
    return "auth" if devise_controller?

    "application"
  end

  private

  def init_breadcrumbs
    @breadcrumbs = []
  end

  def authenticate_client!
    unless client_signed_in?
      respond_to do |format|
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
        format.all do
          redirect_to(
            (I18n.locale.to_s == "en" ? new_client_session_en_path(locale: :en) : new_client_session_path),
            alert: t("recrivo.auth.login_required")
          )
        end
      end
    end
  end
end
