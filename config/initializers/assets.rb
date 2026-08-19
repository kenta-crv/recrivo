# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '3.15'
Rails.application.config.assets.precompile += %w(
  turbo.js
  meetia_page_init.js
  db_v2_pricing_slider.js
  interview.js
  interview.css
  dashboard.css
  dashboard.js
  recrivo_lp.css
  tops.css
  lp_fonts.css
  auth.css
)
# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
