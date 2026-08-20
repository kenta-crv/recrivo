module ApplicationHelper
  SITE_NAME = "Recrivo".freeze
  DEFAULT_TITLE = "AI面接サービス｜人とAIの力で、より良い出会いを".freeze
  DEFAULT_DESCRIPTION = "Recrivoは、AIが面接をサポートすることで、企業と候補者の可能性を最大限に引き出します。".freeze

  def admin_auth_screen?
    controller_path.to_s.start_with?("admins/")
  end

  # 本番で未プリコンパイルの CSS があっても認証画面ごと 500 にしない
  def stylesheet_link_tag_if_compiled(source, **options)
    stylesheet_link_tag(source, **options)
  rescue Sprockets::Rails::Helper::AssetNotFound => e
    Rails.logger.error("[assets] missing precompiled stylesheet #{source}: #{e.message}")
    nil
  end

  def default_meta_tags
    {
      site: SITE_NAME,
      title: DEFAULT_TITLE,
      description: DEFAULT_DESCRIPTION,
      canonical: site_canonical_url,
      charset: "UTF-8",
      reverse: true,
      separator: "|",
      icon: [
        { href: image_path("favicon.ico") },
        { href: image_path("favicon.ico"), rel: "apple-touch-icon" },
      ],
      og: {
        site_name: SITE_NAME,
        title: :title,
        description: :description,
        type: "website",
        url: :canonical,
        image: site_og_image_url,
        locale: (I18n.locale.to_s == "en" ? "en_US" : "ja_JP"),
      },
      twitter: {
        card: "summary_large_image",
        title: :title,
        description: :description,
        image: site_og_image_url,
      },
    }
  end

  def site_canonical_url
    "#{request.base_url}#{request.path}"
  end

  def site_og_image_url
    image_url("recrivo_hero_screen.png")
  end

  def site_public_host
    host = ENV["APP_HOST"].presence || "https://#{ENV.fetch('RAILS_ALLOWED_HOST', 'recrivo.pro')}"
    host = "https://#{host}" unless host.match?(%r{\Ahttps?://}i)
    host.chomp("/")
  end

  def english_ui?
    I18n.locale.to_s == "en"
  end

  def client_sign_in_path_for_locale
    english_ui? ? new_client_session_en_path(locale: :en) : new_client_session_path
  end

  def client_sign_up_path_for_locale
    english_ui? ? new_client_registration_en_path(locale: :en) : new_client_registration_path
  end

  def client_password_new_path_for_locale
    english_ui? ? new_client_password_en_path(locale: :en) : new_client_password_path
  end

  def client_session_url_for_locale
    english_ui? ? client_session_en_path(locale: :en) : session_path(:client)
  end

  def client_registration_url_for_locale
    english_ui? ? client_registration_en_path(locale: :en) : registration_path(:client)
  end

  def client_password_url_for_locale
    english_ui? ? client_password_en_path(locale: :en) : password_path(:client)
  end

  def client_password_update_url_for_locale
    english_ui? ? client_password_en_path(locale: :en) : password_path(:client)
  end

  def plans_path_for_locale
    english_ui? ? localized_plans_path(locale: :en) : plans_path
  end

  def select_plan_path_for_locale
    english_ui? ? localized_select_plan_path(locale: :en) : select_plan_path
  end

  # LP 用 JSON-LD（Organization / WebSite / SoftwareApplication / FAQPage）
  def lp_structured_data
    host = request.base_url
    {
      "@context" => "https://schema.org",
      "@graph" => [
        {
          "@type" => "Organization",
          "name" => SITE_NAME,
          "legalName" => "株式会社J Work",
          "url" => host,
          "logo" => image_url("favicon.ico"),
          "description" => DEFAULT_DESCRIPTION,
          "address" => {
            "@type" => "PostalAddress",
            "streetAddress" => "浜松町２丁目２番１５号２Ｆ",
            "addressLocality" => "港区",
            "addressRegion" => "東京都",
            "addressCountry" => "JP",
          },
        },
        {
          "@type" => "WebSite",
          "name" => SITE_NAME,
          "url" => host,
          "inLanguage" => I18n.locale.to_s,
          "publisher" => { "@type" => "Organization", "name" => "株式会社J Work" },
        },
        {
          "@type" => "SoftwareApplication",
          "name" => SITE_NAME,
          "applicationCategory" => "BusinessApplication",
          "operatingSystem" => "Web",
          "description" => DEFAULT_DESCRIPTION,
          "offers" => {
            "@type" => "Offer",
            "price" => "0",
            "priceCurrency" => "JPY",
            "description" => I18n.t("recrivo.lp.cta_trial", default: "無料トライアルあり"),
          },
        },
        {
          "@type" => "FAQPage",
          "mainEntity" => faq_items.map do |item|
            {
              "@type" => "Question",
              "name" => item[:q],
              "acceptedAnswer" => {
                "@type" => "Answer",
                "text" => item[:a],
              },
            }
          end,
        },
      ],
    }
  end

  def lp_structured_data_json
    lp_structured_data.to_json.html_safe
  end

  def yahoo_ads_conversion_tags
    <<~HTML.html_safe
      <script>
        ytag({
          "type":"yjad_conversion",
          "config":{
            "yahoo_ydn_conv_io": "3LsTvKiI1CWLYpM0iEzVcQ..",
            "yahoo_ydn_conv_label": "OS76L09XX08810RLPU1366130",
            "yahoo_ydn_conv_transaction_id": "",
            "yahoo_ydn_conv_value": "1",
            "yahoo_email": "",
            "yahoo_phone_number": ""
          }
        });
        ytag({
          "type": "yss_conversion",
          "config": {
            "yahoo_conversion_id": "1001407956",
            "yahoo_conversion_label": "Y7OuCIfD4tkcEIu2l7NE",
            "yahoo_conversion_value": "1"
          }
        });
      </script>
    HTML
  end
end
