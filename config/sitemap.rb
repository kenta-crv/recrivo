require Rails.root.join("lib/public_sitemap")

host = "https://recrivo.pro"
entries = PublicSitemap.compose(
  host: host,
  static_entries: [
    { path: "/", changefreq: "weekly", priority: 1.0 },
    { path: "/en", changefreq: "weekly", priority: 0.9 },
    { path: "/security", changefreq: "monthly", priority: 0.6 },
    { path: "/en/security", changefreq: "monthly", priority: 0.5 }
  ]
)

PublicSitemap.write!(host: host, entries: entries)
