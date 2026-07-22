class ApplicationController < ActionController::Base
  include MetaTags::ControllerHelper

  layout :layout_for_request

  before_action :init_breadcrumbs
  before_action :set_active_storage_url_options
  helper_method :breadcrumbs
  before_action :check_trial_expiration

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
  protected

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

  def after_sign_in_path_for(resource)
    case resource
    when Admin
      dashboard_root_path
    when Client
      dashboard_root_path
    else
      root_path
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  def layout_for_request
    return "auth" if devise_controller?

    "application"
  end

  private

  def init_breadcrumbs
    @breadcrumbs = []
  end

  # ここを修正：生のJSONではなく、普通のブラウザアクセス時はログイン画面へ強制リダイレクトさせます
  def authenticate_client!
    unless client_signed_in?
      respond_to do |format|
        # APIや非同期通信からのリクエストに対してはJSONを返す
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
        # 通常のブラウザによるリンク移動やアクセスに対しては、企業用ログイン画面へリダイレクト
        format.all  { redirect_to new_client_session_path, alert: 'ログインが必要です。' }
      end
    end
  end
end