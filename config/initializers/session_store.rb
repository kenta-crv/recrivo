# 同一ホストで他アプリ（meetia / drafity 等）と Cookie が衝突しないよう固有キーにする。
# ブラウザはポートを区別しないため、キーが同じだと CSRF / ログインが壊れる。
Rails.application.config.session_store :cookie_store, key: "_recrivo_session"
