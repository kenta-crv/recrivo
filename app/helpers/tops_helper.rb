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
    # service
    { category: "service", q: "AI Interviewで何ができますか？", a: "採用の一次面接と、営業資料を使った初回商談の両方に使えます。招待リンクを送るだけで、AIが音声対話を進め、スコア・合否・関心トピックをダッシュボードに残します。" },
    { category: "service", q: "候補者・見込み客にアカウントは必要ですか？", a: "不要です。発行した招待リンクからゲストとして参加できます。ログインやインストールは不要です。" },
    { category: "service", q: "途中で離脱した場合、再開できますか？", a: "シナリオ設定で再開可能にできます。再開回数の上限やリンクの有効期限も設定できます。" },
    { category: "service", q: "合否や見込み度はどう決まりますか？", a: "回答内容をAIが評価し、シナリオに設定した合格点・必須項目・関心シグナルをもとに自動判定します。基準はシナリオごとに変更できます。" },
    { category: "service", q: "日本語と英語に対応していますか？", a: "はい。シナリオ単位で言語を指定でき、評価もその言語に合わせて動作します。" },

    # pricing
    { category: "pricing", q: "無料トライアルの条件は？", a: "#{Subscription::TRIAL_DAYS}日間・0円です。上限はシナリオ3本・月間面接20件。トライアル開始時にクレジットカード登録が必要で、期間終了後はスタンダード（月額59,800円）へ移行します。" },
    { category: "pricing", q: "料金プランと上限を教えてください。", a: "スターター月額29,800円（シナリオ3・月100面接）／スタンダード59,800円（10・500、フォロー自動化あり）／Business 98,000円（30・2,000、優先サポートあり）／エンタープライズ198,000円（シナリオ・面接とも無制限）。詳細は料金表をご確認ください。" },
    { category: "pricing", q: "トライアル中に解約したら課金されますか？", a: "トライアル期間中に解約すれば、有料プランへの移行前に停止できます。解約後も契約期間の終了日までは利用できます。" },
    { category: "pricing", q: "プラン変更や請求書払いはできますか？", a: "プラン変更は管理画面からいつでも可能です。請求書払いは契約内容により対応できる場合があります。法人でご希望の場合はお問い合わせください。" },

    # setup
    { category: "setup", q: "申し込みから初回面接までの手順は？", a: "①「無料トライアル」からアカウント登録（会社名・氏名・連絡先など）→②料金プラン画面でトライアルを選択→③クレジットカード登録（Stripe）→④管理画面でシナリオを作成→⑤招待リンクを候補者へ送付、の順です。リンク送付後すぐ実施できます。" },
    { category: "setup", q: "始めるときに用意するものは？", a: "面接なら質問文・合格点・必須項目、商談なら説明用資料です。専門知識は不要で、管理画面から登録するだけで開始できます。" },
    { category: "setup", q: "候補者への案内はどうすればよいですか？", a: "シナリオごとに発行される招待リンクを、メールやチャットで送るだけです。相手側のアカウント作成は不要です。" },
    { category: "setup", q: "既存の採用・営業フローに組み込めますか？", a: "はい。一次面接や初回商談の入口として使い、結果を見て人が本査定・本商談に進める運用が一般的です。" },

    # usage
    { category: "usage", q: "結果はどこで確認できますか？", a: "管理画面のダッシュボードで、スコア・合否・関心トピック・対話ログを確認できます。" },
    { category: "usage", q: "フォローや通知は自動化できますか？", a: "スタンダード以上で、不合格通知や商談後フォローなどの次アクションを自動化できます。トライアル・スターターには含まれません。" },
    { category: "usage", q: "複数のシナリオを並行運用できますか？", a: "はい。職種や商材ごとにシナリオ／資料を分けて運用できます。同時に持てる本数はプランのシナリオ上限に従います。" },
    { category: "usage", q: "招待リンクは誰でも使えますか？", a: "リンクを知っている相手が参加できます。期限や再開回数を設定し、運用範囲をコントロールできます。対話ログは契約企業の権限ユーザーのみ閲覧できます。" }
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
    { num: "01", image: "service_01_scenario.png", alt: "面接シナリオ設計画面", title: "シナリオの作成", desc: "面接質問・合格点・評価基準を設定し、自社の一次対応をテンプレート化します。" },
    { num: "02", image: "service_02_interview.png", alt: "招待リンクからAI面接を実施する画面", title: "招待リンクで実施", desc: "候補者はURLから入室。ログイン不要で、AIが音声面接を進めます。" },
    { num: "03", image: "service_03_results.png", alt: "評価結果とフォローを可視化する画面", title: "結果とフォローの自動化", desc: "スコア・合否・関心トピックを可視化し、次アクションまでつなげます。" }
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
    { icon: "fa-face-smile", label: "顧客満足度", num: "97.5", unit: "%" },
    { icon: "fa-building", label: "累計導入社数", num: "500", unit: "+社" },
    { icon: "fa-clock", label: "対応体制", num: "24", unit: "時間" }
  ].freeze

  COMPARE_ROWS = [
    { label: "初回対応", icon: "fa-bolt", legacy: "日程調整後に人が実施", meetia: "招待リンクですぐAI面接／商談開始" },
    { label: "対応時間", icon: "fa-clock", legacy: "担当者の稼働時間に依存", meetia: "24時間365日参加可能" },
    { label: "評価・記録", icon: "fa-chart-line", legacy: "メモが属人化", meetia: "スコア・見込み度・ログを自動保存" },
    { label: "評価の公平性", icon: "fa-scale-balanced", legacy: "面接官ごとに判定がばらつく", meetia: "同一シナリオで合否・スコアを統一" },
    { label: "運用工数", icon: "fa-users", legacy: "一次対応に人が張り付く", meetia: "AIが入口対応し、人は見極めに集中" }
  ].freeze

  FAQ_CATEGORIES = [
    ["service", "サービスについて", "fa-comments"],
    ["pricing", "料金・トライアル", "fa-yen-sign"],
    ["setup", "申し込み・開始", "fa-rocket"],
    ["usage", "使い方・運用", "fa-chart-line"]
  ].freeze

  TRIAL_FEATURES = [
    { icon: "fa-rocket", label: "即日スタート", desc: "シナリオを用意してリンクを送るだけで、すぐに体験できます。" },
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
