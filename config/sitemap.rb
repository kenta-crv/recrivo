# 公開ページのみ掲載。認証必須・招待トークン・API は載せない。
# 本番ホストは APP_HOST（例: https://recrivo.pro）を優先。未設定時は RAILS_ALLOWED_HOST。
host = ENV["APP_HOST"].presence || "https://#{ENV.fetch('RAILS_ALLOWED_HOST', 'recrivo.pro')}"
host = "https://#{host}" unless host.match?(%r{\Ahttps?://}i)
SitemapGenerator::Sitemap.default_host = host.chomp("/")

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: "weekly", priority: 1.0
  add new_client_registration_path, changefreq: "monthly", priority: 0.7
  add new_client_session_path, changefreq: "monthly", priority: 0.5
end
