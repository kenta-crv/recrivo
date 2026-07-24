module ApplicationHelper
  SITE_NAME = "Recrivo".freeze
  DEFAULT_TITLE = "AI Interview System".freeze
  DEFAULT_DESCRIPTION = "Automate first-round hiring interviews with AI. Create scenarios, send invite links, evaluate voice answers, and decide pass/fail end to end.".freeze

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
        locale: "ja_JP",
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
    image_url("top_hero.png")
  end

  def site_public_host
    host = ENV["APP_HOST"].presence || "https://#{ENV.fetch('RAILS_ALLOWED_HOST', 'recrivo.pro')}"
    host = "https://#{host}" unless host.match?(%r{\Ahttps?://}i)
    host.chomp("/")
  end

  # LP 用 JSON-LD（Organization / WebSite / SoftwareApplication / FAQPage）
  def lp_structured_data
    host = request.base_url
    {
      "@context" => "https://schema.org",
      "@graph" => [
        {
          "@type" => "Organization",
          "name" => "株式会社J Work",
          "url" => host,
          "logo" => image_url("meetia_logo.png"),
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
          "inLanguage" => "ja",
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
            "description" => "無料トライアルあり",
          },
        },
        {
          "@type" => "FAQPage",
          "mainEntity" => TopsHelper::FAQ_ITEMS.map do |item|
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
end
