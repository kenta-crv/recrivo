module TopsHelper
  HERO_FEATURE_CARDS = [
    ["fa-list-check", "シナリオ／資料設計", "面接質問も営業資料も、企業ごとに設計"],
    ["fa-link", "招待リンクで開始", "候補者・見込み客はログイン不要で参加"],
    ["fa-microphone-lines", "音声対話の実施", "AIが質問・提案しながらリアルタイム対話"],
    ["fa-clipboard-check", "評価・見込み度", "スコア・合否・関心トピックを自動可視化"],
    ["fa-shield-halved", "セキュアな環境", "企業向けのアクセス制御と暗号化"]
  ].freeze

  LP_NAV_ITEMS = [
    { key: "whats", label: "AI Interviewとは", href: "#whats" },
    { key: "service", label: "サービス", href: "#service" },
    { key: "features", label: "機能", href: "#features" },
    { key: "pricing", label: "料金", href: "#pricing" },
    { key: "reviews", label: "レビュー", href: "#reviews" },
    { key: "faq", label: "FAQ", href: "#faq" },
    { key: "company", label: "会社概要", href: "#company" }
  ].freeze

  FEATURE_TABS = [
    %w[scenario シナリオ],
    %w[invite 招待リンク],
    %w[evaluate 評価],
    %w[results 結果]
  ].freeze

  FEATURE_ROWS = [
    ["01", "fa-list-check", "面接シナリオ／商談資料の設計", "質問・合格点・資料トーク・フォロールールをテンプレート化できます。", %w[分岐質問 合格点設定 資料連動]],
    ["02", "fa-link", "招待リンクで即開始", "候補者・見込み客にURLを送るだけ。ログイン不要で面接／商談を開始できます。", %w[ゲスト参加 トークン再開 期限管理]],
    ["03", "fa-microphone-lines", "音声で進むAI対話", "AIがシナリオや資料に沿って質問・提案。音声回答を文字起こしして評価します。", %w[STT TTS リアルタイム対話]],
    ["04", "fa-clipboard-check", "合否・見込み度の可視化", "スコア集計、合否、関心トピック、次アクションまで自動生成します。", %w[合否自動判定 見込み度 結果閲覧]],
    ["05", "fa-chart-line", "オペレーション可視化", "実施数・結果一覧・月間上限を管理画面で把握できます。", %w[月次上限 結果一覧 管理画面]],
    ["06", "fa-bell", "フォロー自動化", "不合格通知や商談後フォローメールなど、次アクションを早めます。", %w[自動通知 フォロー予約 再開制限]]
  ].freeze

  FAQ_ITEMS = [
    { category: "service", q: "候補者や見込み客にアカウントは必要ですか？", a: "不要です。企業から発行した招待リンクから、ゲストとしてそのまま参加できます。" },
    { category: "pricing", q: "無料トライアルの期間は？", a: "#{Subscription::TRIAL_DAYS}日間の無料トライアルをご用意しています。クレジットカード登録後、すぐにシナリオ／資料の準備を始められます。" },
    { category: "service", q: "面接と商談の両方に使えますか？", a: "はい。採用の一次面接シナリオにも、営業資料を用いた初回商談にも対応しています。" },
    { category: "service", q: "途中で離脱した場合は再開できますか？", a: "シナリオ設定により再開可能です。再開回数の上限も設定できます。" },
    { category: "security", q: "セキュリティ対策は？", a: "通信の暗号化、アクセストークン、レート制限、アップロード検証など企業向けの対策を実施しています。" },
    { category: "setup", q: "導入までどのくらいかかりますか？", a: "シナリオや資料を登録し、招待リンクを共有すれば当日から運用を開始できます。" },
    { category: "service", q: "日本語と英語に対応していますか？", a: "はい。シナリオ単位で言語を指定し、評価プロンプトも言語に合わせて動作します。" },
    { category: "support", q: "合否や見込み度はどう決まりますか？", a: "回答内容をAIが評価し、合格点・必須項目・関心シグナルに基づいて自動判定します。" },
    { category: "pricing", q: "プラン変更は可能ですか？", a: "管理画面からいつでもプランのアップグレード・ダウングレードが可能です。" }
  ].freeze

  REVIEW_CARDS = [
    { meta: "IT企業（人事責任者）", title: "一次面接の工数が大幅に減りました", quote: "「毎週の一次面接対応に追われていましたが、AI Interview導入後は招待リンクを送るだけでスクリーニングが進みます。」", metric: "一次対応工数 -45%" },
    { meta: "SaaS企業（営業企画）", title: "資料請求後の初回商談が止まらなくなりました", quote: "「夜間の資料ダウンロードにもAIが即対応。朝には見込み度と関心トピックが揃っています。」", metric: "初回接触スピード向上" },
    { meta: "人材紹介（採用コンサル）", title: "夜間・休日の受験にも対応できました", quote: "「候補者の都合に合わせた面接枠がボトルネックでした。今はリンク送付後に好きな時間で受験できます。」", metric: "24h 受験対応" },
    { meta: "メーカー（採用担当）", title: "評価基準が揃い、判断が安定しました", quote: "「面接官ごとの評価差が課題でしたが、同じシナリオで同じ基準の採点になるため判断が安定しました。」", metric: "評価ばらつき改善" },
    { meta: "スタートアップ（CEO）", title: "少人数でも選考と商談を止めずに回せます", quote: "「採用も営業も専任が薄い体制でも、AIが入口対応を担い、人間は見極めに集中できています。」", metric: "選考・商談スピード向上" }
  ].freeze

  PROBLEM_ITEMS = [
    { icon: "fa-clock", text: "一次面接・初回商談の日程調整に時間がかかり、<br>相手の熱量が冷めてしまう", desc: "担当者の空きに依存し、初回接触までに日数が空いて離脱が増える。" },
    { icon: "fa-moon", text: "夜間・休日の受験／資料請求に<br>対応しきれない", desc: "相手の都合に合わせた枠を十分に用意できず、機会損失が起きる。" },
    { icon: "fa-users", text: "担当者ごとの評価差で<br>判断が安定しない", desc: "評価観点が属人化し、同じ回答でも判定が揺れる。" },
    { icon: "fa-clipboard-list", text: "対話ログが残らず、<br>振り返りと改善ができない", desc: "記録の粒度がバラバラで、選考・営業改善にデータを使えない。" },
    { icon: "fa-headset", text: "入口対応に工数がかかり、<br>本査定や本商談に集中できない", desc: "スクリーニングに時間が取られ、見極めや提案の深掘りが後回しになる。" },
    { icon: "fa-chart-line", text: "応募・リードは増えているのに<br>スループットが伸びない", desc: "入口は増えても、実施と評価の仕組みがボトルネックになっている。" }
  ].freeze

  SERVICE_CARDS = [
    { num: "01", icon: "fa-list-check", orbit: "fa-pen-to-square", title: "シナリオ／資料の作成", desc: "面接質問や営業資料、合格点・フォロールールを設定し、自社の入口対応をテンプレート化します。" },
    { num: "02", icon: "fa-link", orbit: "fa-user-check", title: "招待リンクで実施", desc: "相手はURLから入室。AIが音声で質問・提案し、回答をその場で評価します。" },
    { num: "03", icon: "fa-clipboard-check", orbit: "fa-chart-pie", title: "結果とフォローの自動化", desc: "スコア・合否・見込み度・関心トピックを可視化し、次アクションまでつなげます。" }
  ].freeze

  COMPANY_PROFILE = [
    ["会社名", "株式会社Ri-Plus"],
    ["代表取締役", "奥山　健太"],
    ["設立", "2020年4月2日"],
    ["資本金", "1,000,000円"],
    ["所在地", "東京都中央区銀座1-22-11 2F"],
    ["事業内容", "AI面接・商談サービス「AI Interview」の開発・提供"]
  ].freeze

  COMPANY_STATS = [
    { icon: "fa-calendar", label: "顧客満足度", num: "97.5", unit: "%" },
    { icon: "fa-building", label: "累計導入社数", num: "500", unit: "+社" },
    { icon: "fa-clock", label: "対応体制", num: "24", unit: "時間" }
  ].freeze

  COMPARE_ROWS = [
    { label: "初回対応", icon: "fa-bolt", legacy: "日程調整後に人が実施", meetia: "招待リンクですぐAI面接／商談開始" },
    { label: "対応時間", icon: "fa-clock", legacy: "担当者の稼働時間に依存", meetia: "24時間365日参加可能" },
    { label: "評価・記録", icon: "fa-chart-line", legacy: "メモが属人化", meetia: "スコア・見込み度・ログを自動保存" }
  ].freeze

  FAQ_CATEGORIES = [
    ["service", "サービスについて", "fa-comments"],
    ["pricing", "料金", "fa-yen-sign"],
    ["setup", "導入", "fa-rocket"],
    ["security", "セキュリティ", "fa-shield-halved"],
    ["support", "サポート", "fa-headset"]
  ].freeze

  TRIAL_FEATURES = [
    { icon: "fa-rocket", label: "即日スタート", desc: "シナリオや資料を用意してリンクを送るだけで、すぐに体験できます。" },
    { icon: "fa-shield-halved", label: "セキュア設計", desc: "トークン認証と暗号化で、企業利用にも安心の環境を提供します。" },
    { icon: "fa-chart-simple", label: "成果を可視化", desc: "合否・スコア・見込み度・回答ログをダッシュボードで確認できます。" }
  ].freeze

  def lp_nav_active?(key)
    @lp_page == key.to_s
  end

  def lp_sign_up_path
    new_client_registration_path
  end

  def lp_trial_experience_path
    if client_signed_in? || admin_signed_in?
      dashboard_root_path
    else
      new_client_registration_path
    end
  end

  def lp_trial_experience_link_options
    {}
  end

  def lp_login_path
    if client_signed_in? || admin_signed_in?
      dashboard_root_path
    else
      new_client_session_path
    end
  end

  def lp_login_label
    if client_signed_in? || admin_signed_in?
      "マイページ"
    else
      "ログイン"
    end
  end
end
