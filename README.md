# AI Interview

Meetia から切り出した **AI面接サービス**（独立Railsアプリ）。

## できること

- 企業が面接シナリオ・質問を作成
- 招待リンク（`/i/:token`）で候補者が受験
- 音声/選択式回答の評価・合否
- ダッシュボードで結果確認
- Stripe によるプラン課金（Meetia 基盤を面接向けに再定義）

## セットアップ

```bash
cd /Users/okuyamakenta/Program/ai-interview
bundle install
yarn install   # 必要な場合
bin/rails db:prepare
bin/rails s
```

環境変数（最低限）:

- `OPENAI_API_KEY`
- Stripe 関連（課金を使う場合）

## 主なルート

| パス | 用途 |
|------|------|
| `/` | LP |
| `/interview` | 受験ポータル |
| `/i/:token` | シナリオ招待リンク |
| `/situations` | シナリオ管理（企業ログイン） |
| `/dashboard` | 企業ダッシュボード |
| `/api/interviews/*` | 面接API |

## Meetia との関係

- 別ディレクトリ・別DB・別デプロイ前提
- データ移行は初期は行わない（新規利用）
# recrivo
