module TopsHelper
  HERO_FEATURE_CARDS = [
    ["fa-list-check", "シナリオ設計", "質問・合格点・自動合否を企業ごとに設定"],
    ["fa-link", "招待リンク受験", "候補者はログイン不要でそのまま開始"],
    ["fa-microphone-lines", "音声回答評価", "STTとLLMで回答を採点・要約"],
    ["fa-clipboard-check", "合否の可視化", "結果・スコア・回答ログをダッシュボードで確認"],
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
    ["01", "fa-list-check", "面接シナリオ設計", "質問・必須項目・合格点・タイムアウト・自動不合格をシナリオ単位で設計できます。", %w[分岐質問 合格点設定 再開制御]],
    ["02", "fa-link", "招待リンクで受験開始", "候補者にURLを送るだけ。ログイン不要で面接を開始できます。", %w[ゲスト受験 トークン再開 期限管理]],
    ["03", "fa-microphone-lines", "音声・選択式の回答評価", "音声回答は文字起こしし、LLMが関連性・正確性・明瞭さを採点します。", %w[STT TTS 非同期評価]],
    ["04", "fa-clipboard-check", "合否判定と結果共有", "スコア集計から合否・サマリーまで自動生成。企業ダッシュボードで確認できます。", %w[合否自動判定 強み弱み 結果閲覧]],
    ["05", "fa-chart-line", "採用オペレーション可視化", "シナリオ数・月間面接数・結果一覧を管理画面で把握できます。", %w[月次上限 結果一覧 管理画面]],
    ["06", "fa-bell", "不合格時の通知", "設定に応じてアプリ内/メールで通知し、次アクションを早めます。", %w[自動不合格 通知設定 再開制限]]
  ].freeze

  FAQ_ITEMS = [
    { category: "service", q: "候補者にアカウントは必要ですか？", a: "不要です。企業から発行した招待リンクから、ゲストとしてそのまま受験できます。" },
    { category: "pricing", q: "無料トライアルの期間は？", a: "#{Subscription::TRIAL_DAYS}日間の無料トライアルをご用意しています。クレジットカード登録後、すぐにシナリオ作成を始められます。" },
    { category: "service", q: "途中で離脱した場合は再開できますか？", a: "シナリオ設定により再開可能です。再開回数の上限も設定できます。" },
    { category: "security", q: "セキュリティ対策は？", a: "通信の暗号化、アクセストークン、レート制限、アップロード検証など企業向けの対策を実施しています。" },
    { category: "setup", q: "導入までどのくらいかかりますか？", a: "シナリオと質問を作成し、招待リンクを共有すれば当日から運用を開始できます。" },
    { category: "service", q: "日本語と英語に対応していますか？", a: "はい。シナリオ単位で言語を指定し、評価プロンプトも言語に合わせて動作します。" },
    { category: "support", q: "合否はどのように決まりますか？", a: "各回答の評価スコアを集計し、シナリオの合格点・必須設問ルールに基づいて自動判定します。" },
    { category: "pricing", q: "プラン変更は可能ですか？", a: "管理画面からいつでもプランのアップグレード・ダウングレードが可能です。" }
  ].freeze

  REVIEW_CARDS = [
    { meta: "IT企業（人事責任者）", title: "一次面接の工数が大幅に減りました", quote: "「毎週の一次面接対応に追われていましたが、AI Interview導入後は招待リンクを送るだけでスクリーニングが進みます。人事は最終面接に集中できるようになりました。」", metric: "一次対応工数 -45%" },
    { meta: "人材紹介（採用コンサル）", title: "夜間・休日の受験にも対応できました", quote: "「候補者の都合に合わせた面接枠がボトルネックでした。今はリンク送付後に好きな時間で受験でき、月曜朝には結果が揃っています。」", metric: "24h 受験対応" },
    { meta: "SaaS企業（採用マネージャー）", title: "評価基準が揃い、合否のばらつきが減りました", quote: "「面接官ごとの評価差が課題でしたが、同じシナリオで同じ基準の採点になるため、判断が安定しました。」", metric: "評価ばらつき改善" },
    { meta: "メーカー（採用担当）", title: "地方候補の一次面接がスムーズになりました", quote: "「来社前のスクリーニングをオンラインで完結でき、移動コストと日程調整の負担が減りました。」", metric: "日程調整コスト削減" },
    { meta: "スタートアップ（CEO）", title: "少人数でも採用選考を止めずに回せます", quote: "「採用専任がいない体制でも、AIが一次面接を担い、人間は通過者の最終確認に集中できています。」", metric: "選考スピード向上" }
  ].freeze

  PROBLEM_ITEMS = [
    { icon: "fa-clock", text: "一次面接の日程調整に時間がかかり、<br>候補者の熱量が冷めてしまう", desc: "面接官の空き状況に依存し、初回接触までに日数が空いて離脱が増える。" },
    { icon: "fa-moon", text: "夜間・休日の受験希望に<br>対応しきれない", desc: "候補者の都合に合わせた枠を十分に用意できず、機会損失が起きる。" },
    { icon: "fa-users", text: "面接官ごとの評価差で<br>合否判断が安定しない", desc: "評価観点が属人化し、同じ回答でも判定が揺れる。" },
    { icon: "fa-clipboard-list", text: "面接メモが残らず、<br>振り返りと改善ができない", desc: "記録の粒度がバラバラで、選考基準の改善にデータを使えない。" },
    { icon: "fa-headset", text: "一次対応に工数がかかり、<br>最終面接に集中できない", desc: "スクリーニングに時間が取られ、見極めるべき候補への深掘りが後回しになる。" },
    { icon: "fa-chart-line", text: "応募は増えているのに<br>選考スループットが伸びない", desc: "入口は増えても、面接実施と評価の仕組みがボトルネックになっている。" }
  ].freeze

  SERVICE_CARDS = [
    { num: "01", icon: "fa-list-check", orbit: "fa-pen-to-square", title: "シナリオ作成", desc: "質問・合格点・再開ルールを設定し、自社の一次面接をテンプレート化します。" },
    { num: "02", icon: "fa-link", orbit: "fa-user-check", title: "招待リンクで受験", desc: "候補者はURLから入室。音声または選択式で回答し、AIが評価します。" },
    { num: "03", icon: "fa-clipboard-check", orbit: "fa-chart-pie", title: "合否・結果の可視化", desc: "スコア・サマリー・回答ログをダッシュボードで確認し、次の選考へ進めます。" }
  ].freeze

  COMPANY_PROFILE = [
    ["会社名", "株式会社J Work"],
    ["代表取締役", "奥山　健太"],
    ["設立", "2023年8月22日"],
    ["資本金", "5,000,000円"],
    ["所在地", "東京都港区浜松町２丁目２番１５号２Ｆ"],
    ["事業内容", "AI面接サービス「AI Interview」の開発・提供"]
  ].freeze

  COMPANY_STATS = [
    { icon: "fa-calendar", label: "サービス開始", num: "2026", unit: "年" },
    { icon: "fa-building", label: "対象", num: "採用", unit: "チーム" },
    { icon: "fa-clock", label: "対応体制", num: "24", unit: "時間" }
  ].freeze

  COMPARE_ROWS = [
    { label: "初回面接", icon: "fa-bolt", legacy: "日程調整後に人が実施", meetia: "招待リンクですぐAI面接開始" },
    { label: "対応時間", icon: "fa-clock", legacy: "面接官の稼働時間に依存", meetia: "24時間365日受験可能" },
    { label: "評価・記録", icon: "fa-chart-line", legacy: "メモが属人化", meetia: "スコア・合否・ログを自動保存" }
  ].freeze

  FAQ_CATEGORIES = [
    ["service", "サービスについて", "fa-comments"],
    ["pricing", "料金", "fa-yen-sign"],
    ["setup", "導入", "fa-rocket"],
    ["security", "セキュリティ", "fa-shield-halved"],
    ["support", "サポート", "fa-headset"]
  ].freeze

  TRIAL_FEATURES = [
    { icon: "fa-rocket", label: "即日スタート", desc: "シナリオを作ってリンクを送るだけで、すぐにAI面接を体験できます。" },
    { icon: "fa-shield-halved", label: "セキュア設計", desc: "トークン認証と暗号化で、企業利用にも安心の環境を提供します。" },
    { icon: "fa-chart-simple", label: "成果を可視化", desc: "合否・スコア・回答ログをダッシュボードで確認できます。" }
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
