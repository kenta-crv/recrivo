module TopsHelper
  HERO_FEATURE_CARDS = [
    ["fa-list-check", "シナリオ設計", "質問・合格点・必須項目・フォロールールを、職種ごとにテンプレート化"],
    ["fa-link", "招待リンクで開始", "候補者はログイン不要。URLを開くだけで面接ルームに入室"],
    ["fa-microphone-lines", "音声対話の実施", "AIがシナリオに沿って質問・深掘り。回答はリアルタイムで文字起こし"],
    ["fa-clipboard-check", "評価・合否判定", "スコア集計から合否判定、回答ログまで自動でダッシュボードに反映"],
    ["fa-shield-halved", "セキュアな環境", "企業向けのアクセス制御と暗号化で、安心して運用可能"]
  ].freeze

  HERO_FEATURE_CARDS_EN = [
    ["fa-list-check", "Scenario design", "Template questions, passing scores, required items, and follow-up rules by role"],
    ["fa-link", "Start via invite link", "Candidates join with no login — open the URL and enter the interview room"],
    ["fa-microphone-lines", "Voice dialogue", "AI asks and probes along your scenario; answers are transcribed in real time"],
    ["fa-clipboard-check", "Scoring & pass/fail", "Scores, decisions, and response logs appear on the dashboard automatically"],
    ["fa-shield-halved", "Secure by design", "Access controls and encryption built for business use"]
  ].freeze

  LP_NAV_ITEMS = [
    { key: "whats", label: "AI Interviewとは", href: "#whats" },
    { key: "service", label: "サービス", href: "#service" },
    { key: "features", label: "機能", href: "#features" },
    { key: "pricing", label: "料金", href: "#pricing" },
    { key: "reviews", label: "レビュー", href: "#reviews" },
    { key: "faq", label: "FAQ", href: "#faq" },
    { key: "company", label: "会社概要", href: "#company" },
    { key: "columns", label: "お役立ち記事", href: "/columns" }
  ].freeze

  LP_NAV_ITEMS_EN = [
    { key: "whats", label: "About", href: "#whats" },
    { key: "service", label: "Service", href: "#service" },
    { key: "features", label: "Features", href: "#features" },
    { key: "pricing", label: "Pricing", href: "#pricing" },
    { key: "reviews", label: "Reviews", href: "#reviews" },
    { key: "faq", label: "FAQ", href: "#faq" },
    { key: "company", label: "Company", href: "#company" },
    { key: "columns", label: "Articles", href: "/columns" }
  ].freeze

  FEATURED_COLUMNS = [
    { title: "AI面接が変える採用一次対応の未来", path: "/columns/ai-interview-first-round-future" },
    { title: "一次面接の日程調整を減らす運用設計", path: "/columns/reduce-first-interview-scheduling" },
    { title: "AI面接の評価基準の作り方と公平性", path: "/columns/ai-interview-scoring-fairness" },
    { title: "招待リンクで進める候補者体験の設計", path: "/columns/invite-link-candidate-experience" },
    { title: "採用DXで一次面接をスケールさせるポイント", path: "/columns/scale-first-round-with-ai" }
  ].freeze

  FEATURED_COLUMNS_EN = [
    { title: "How AI interviews reshape first-round hiring", path: "/columns/ai-interview-first-round-future" },
    { title: "Cut first-round scheduling friction", path: "/columns/reduce-first-interview-scheduling" },
    { title: "Building fair AI interview scoring rubrics", path: "/columns/ai-interview-scoring-fairness" },
    { title: "Designing candidate experience with invite links", path: "/columns/invite-link-candidate-experience" },
    { title: "Scaling first-round interviews with recruiting DX", path: "/columns/scale-first-round-with-ai" }
  ].freeze

  FEATURE_ROWS = [
    ["01", "fa-list-check", "面接シナリオの設計", "質問・合格点・必須項目・フォロールールをテンプレート化できます。", %w[分岐質問 合格点設定 評価基準]],
    ["02", "fa-link", "招待リンクで即開始", "候補者にURLを送るだけ。ログイン不要でAI面接を開始できます。", %w[ゲスト参加 トークン再開 期限管理]],
    ["03", "fa-microphone-lines", "音声で進むAI面接", "AIがシナリオに沿って質問。音声回答を文字起こしして評価します。", %w[STT TTS リアルタイム対話]],
    ["04", "fa-clipboard-check", "合否・スコアの可視化", "スコア集計、合否判定、回答ログまで自動生成します。", %w[合否自動判定 スコア 結果閲覧]],
    ["05", "fa-chart-line", "オペレーション可視化", "実施数・結果一覧・月間上限を管理画面で把握できます。", %w[月次上限 結果一覧 管理画面]],
    ["06", "fa-bell", "フォロー自動化", "不合格通知やフォローメールなど、次アクションを早めます。", %w[自動通知 フォロー予約 再開制限]]
  ].freeze

  FEATURE_ROWS_EN = [
    ["01", "fa-list-check", "Interview scenario design", "Template questions, passing scores, required items, and follow-up rules.", ["Branching", "Passing score", "Rubrics"]],
    ["02", "fa-link", "Instant start via invite link", "Send a URL — candidates start AI interviews with no login.", ["Guest access", "Resume token", "Expiry"]],
    ["03", "fa-microphone-lines", "Voice-led AI interviews", "AI asks along your scenario. Voice answers are transcribed and scored.", ["STT", "TTS", "Live dialogue"]],
    ["04", "fa-clipboard-check", "Pass/fail & score visibility", "Auto-generate score totals, decisions, and response logs.", ["Auto decision", "Scores", "Result view"]],
    ["05", "fa-chart-line", "Operations visibility", "Track volume, results, and monthly limits in the dashboard.", ["Monthly caps", "Result list", "Admin"]],
    ["06", "fa-bell", "Follow-up automation", "Speed next actions such as rejection notices and follow-up email.", ["Auto notify", "Scheduled follow-up", "Resume limits"]]
  ].freeze

  FAQ_ITEMS = [
    { category: "service", q: "AI Interviewで何ができますか？", a: "採用の一次面接を自動化できます。招待リンクを送るだけで、AIが音声面接を進め、スコア・合否・回答ログをダッシュボードに残します。" },
    { category: "service", q: "候補者にアカウントは必要ですか？", a: "不要です。発行した招待リンクからゲストとして参加できます。ログインやインストールは不要です。" },
    { category: "service", q: "途中で離脱した場合、再開できますか？", a: "シナリオ設定で再開可能にできます。再開回数の上限やリンクの有効期限も設定できます。" },
    { category: "service", q: "合否はどう決まりますか？", a: "回答内容をAIが評価し、シナリオに設定した合格点・必須項目をもとに自動判定します。基準はシナリオごとに変更できます。" },
    { category: "service", q: "日本語と英語に対応していますか？", a: "はい。シナリオ単位で言語を指定でき、評価もその言語に合わせて動作します。" },
    { category: "pricing", q: "無料トライアルの条件は？", a: "#{Subscription::TRIAL_DAYS}日間・0円・カード不要です。上限はシナリオ1本・月間面接5件。終了後は自動課金せず、スタンダード（月額59,800円・初回3ヶ月15%OFF）へ誘導します。" },
    { category: "pricing", q: "料金プランと上限を教えてください。", a: "スタンダード月額59,800円（シナリオ10・月500面接、フォロー自動化あり）／Business 98,000円（30・2,000、優先サポートあり）／エンタープライズ198,000円（シナリオ・面接とも無制限）。詳細は料金表をご確認ください。" },
    { category: "pricing", q: "トライアル中に解約したら課金されますか？", a: "トライアルはカード不要で、期間終了時も自動課金しません。有料プランは管理画面から手動でご契約ください。" },
    { category: "pricing", q: "プラン変更や請求書払いはできますか？", a: "プラン変更は管理画面からいつでも可能です。請求書払いは契約内容により対応できる場合があります。法人でご希望の場合はお問い合わせください。" },
    { category: "setup", q: "申し込みから初回面接までの手順は？", a: "①「無料トライアル」からアカウント登録（メール・パスワードのみ）→②ダッシュボードでトライアル開始→③管理画面でシナリオを作成→④招待リンクを候補者へ送付、の順です。リンク送付後すぐ実施できます。" },
    { category: "setup", q: "始めるときに用意するものは？", a: "面接の質問文・合格点・必須項目です。専門知識は不要で、管理画面から登録するだけで開始できます。" },
    { category: "setup", q: "候補者への案内はどうすればよいですか？", a: "シナリオごとに発行される招待リンクを、メールやチャットで送るだけです。相手側のアカウント作成は不要です。" },
    { category: "setup", q: "既存の採用フローに組み込めますか？", a: "はい。一次面接の入口として使い、結果を見て人が本面接に進める運用が一般的です。" },
    { category: "usage", q: "結果はどこで確認できますか？", a: "管理画面のダッシュボードで、スコア・合否・回答ログを確認できます。" },
    { category: "usage", q: "フォローや通知は自動化できますか？", a: "スタンダード以上で、不合格通知などの次アクションを自動化できます。トライアルには含まれません。" },
    { category: "usage", q: "複数のシナリオを並行運用できますか？", a: "はい。職種ごとにシナリオを分けて運用できます。同時に持てる本数はプランのシナリオ上限に従います。" },
    { category: "usage", q: "招待リンクは誰でも使えますか？", a: "リンクを知っている相手が参加できます。期限や再開回数を設定し、運用範囲をコントロールできます。対話ログは契約企業の権限ユーザーのみ閲覧できます。" }
  ].freeze

  FAQ_ITEMS_EN = [
    { category: "service", q: "What can AI Interview do?", a: "Automate first-round recruiting interviews. Send an invite link and AI runs the voice interview, then stores scores, pass/fail, and response logs on the dashboard." },
    { category: "service", q: "Do candidates need an account?", a: "No. They join as guests from the invite link — no login or install required." },
    { category: "service", q: "Can candidates resume if they leave midway?", a: "Yes, if you enable resume in the scenario settings. You can also set resume limits and link expiry." },
    { category: "service", q: "How is pass/fail decided?", a: "AI scores answers against your scenario’s passing score and required items. Criteria can differ per scenario." },
    { category: "service", q: "Do you support Japanese and English?", a: "Yes. Set language per scenario; scoring follows that language." },
    { category: "pricing", q: "What are the free trial terms?", a: "#{Subscription::TRIAL_DAYS} days at ¥0, no credit card required. Up to 1 scenario and 5 interviews/month. When the trial ends there is no auto-charge — you are guided to Standard (¥59,800/month, 15% off for the first 3 months)." },
    { category: "pricing", q: "What are the plans and limits?", a: "Standard ¥59,800/mo (10 scenarios, 500 interviews, follow-up automation) / Business ¥98,000 (30, 2,000, priority support) / Enterprise ¥198,000 (unlimited scenarios & interviews). See the pricing table for details." },
    { category: "pricing", q: "If I cancel during the trial, am I charged?", a: "The trial needs no card and does not auto-charge when it ends. Start a paid plan anytime from the dashboard." },
    { category: "pricing", q: "Can we change plans or pay by invoice?", a: "Yes — change plans anytime from the dashboard. Invoice payment may be available depending on contract; contact us for corporate needs." },
    { category: "setup", q: "What are the steps from signup to the first interview?", a: "1) Create an account via Free trial (email and password only) → 2) Land on the dashboard with trial started → 3) Build a scenario → 4) Send the invite link to candidates. You can run interviews immediately after sharing the link." },
    { category: "setup", q: "What should we prepare?", a: "Interview questions, passing scores, and required items. No specialist knowledge needed — register them in the dashboard and go." },
    { category: "setup", q: "How should we invite candidates?", a: "Share the per-scenario invite link by email or chat. Candidates don’t create accounts." },
    { category: "setup", q: "Can it fit existing recruiting flows?", a: "Yes. Use it as the first-round gate, then humans advance candidates to later interviews based on results." },
    { category: "usage", q: "Where do we review results?", a: "On the dashboard: scores, pass/fail, and response logs." },
    { category: "usage", q: "Can follow-up and notifications be automated?", a: "On Standard and above, you can automate next actions such as rejection notices. Trial does not include this." },
    { category: "usage", q: "Can we run multiple scenarios in parallel?", a: "Yes — split scenarios by role. Concurrent scenario count follows your plan limit." },
    { category: "usage", q: "Can anyone use an invite link?", a: "Anyone with the link can join. Control scope with expiry and resume limits. Conversation logs are visible only to authorized users on your account." }
  ].freeze

  REVIEW_CARDS = [
    { meta: "IT企業（人事責任者）", title: "一次面接の工数が大幅に減りました", quote: "「毎週の一次面接対応に追われていましたが、AI Interview導入後は招待リンクを送るだけでスクリーニングが進みます。」", metric: "一次対応工数 -45%" },
    { meta: "人材紹介（採用コンサル）", title: "夜間・休日の受験にも対応できました", quote: "「候補者の都合に合わせた面接枠がボトルネックでした。今はリンク送付後に好きな時間で受験できます。」", metric: "24h 受験対応" },
    { meta: "メーカー（採用担当）", title: "評価基準が揃い、判断が安定しました", quote: "「面接官ごとの評価差が課題でしたが、同じシナリオで同じ基準の採点になるため判断が安定しました。」", metric: "評価ばらつき改善" },
    { meta: "スタートアップ（CEO）", title: "少人数でも選考を止めずに回せます", quote: "「採用専任が薄い体制でも、AIが一次面接を担い、人間は見極めに集中できています。」", metric: "選考スピード向上" },
    { meta: "SaaS企業（人事企画）", title: "応募増でも一次対応が追いつくように", quote: "「応募が増えても日程調整に追われず、スコア付きの結果が翌朝には揃っています。」", metric: "一次処理量向上" }
  ].freeze

  REVIEW_CARDS_EN = [
    { meta: "IT company (HR lead)", title: "First-round effort dropped sharply", quote: "“We were buried in weekly first-round interviews. After AI Interview, screening moves forward just by sending invite links.”", metric: "-45% first-line effort" },
    { meta: "Recruiting firm (consultant)", title: "Nights and weekends are covered", quote: "“Candidate availability used to bottleneck us. Now they take interviews whenever they want after getting the link.”", metric: "24h coverage" },
    { meta: "Manufacturer (recruiter)", title: "Consistent criteria, steadier decisions", quote: "“Interviewer variance was a problem. Shared scenarios and scoring made decisions more stable.”", metric: "Less score drift" },
    { meta: "Startup (CEO)", title: "A small team keeps hiring moving", quote: "“Even without a full recruiting team, AI handles first rounds so people focus on final judgment.”", metric: "Faster pipeline" },
    { meta: "SaaS (HR ops)", title: "Volume up without backlog", quote: "“Applications grew, but we no longer chase calendars — scored results are ready by morning.”", metric: "Higher throughput" }
  ].freeze

  PROBLEM_ITEMS = [
    { icon: "fa-clock", text: "一次面接の日程調整で<br>候補者の熱量が冷めてしまう", desc: "担当者の空きに依存し、初回面接までに日数が空いて離脱が増える。" },
    { icon: "fa-moon", text: "夜間・休日の応募に<br>即時対応しきれない", desc: "候補者の都合に合わせた枠を十分に用意できず、機会損失が起きる。" },
    { icon: "fa-users", text: "面接官ごとの評価差で<br>判断が安定しない", desc: "評価観点が属人化し、同じ回答でも判定が揺れる。" },
    { icon: "fa-clipboard-list", text: "面接ログが残らず、<br>振り返りと改善ができない", desc: "記録の粒度がバラバラで、選考改善にデータを使えない。" },
    { icon: "fa-headset", text: "面接の無断欠席で<br>担当者の時間が無駄になる", desc: "一次面接の無断欠席率が低くても、担当者はその時間を確保しなければならない。" },
    { icon: "fa-chart-line", text: "応募は増えているのに<br>選考スループットが伸びない", desc: "入口は増えても、実施と評価の仕組みがボトルネックになっている。" }
  ].freeze

  PROBLEM_ITEMS_EN = [
    { icon: "fa-clock", text: "Scheduling delays cool<br>candidate interest", desc: "Waiting on interviewer availability lets days slip — and drop-off rises." },
    { icon: "fa-moon", text: "Nights and weekends<br>go unanswered", desc: "You can’t offer enough slots around candidate schedules, so opportunities leak." },
    { icon: "fa-users", text: "Interviewer variance<br>makes decisions shaky", desc: "Rubrics stay personal, so the same answer can get different outcomes." },
    { icon: "fa-clipboard-list", text: "Interview logs don’t stick,<br>so improvement stalls", desc: "Uneven notes make it hard to use data to improve hiring." },
    { icon: "fa-headset", text: "No-shows waste<br>interviewer time", desc: "Even a low no-show rate still blocks calendar time for your team." },
    { icon: "fa-chart-line", text: "Applications grow, but<br>pipeline throughput stalls", desc: "Top-of-funnel rises while delivery and scoring remain the bottleneck." }
  ].freeze

  SERVICE_CARDS = [
    { num: "01", image: "service_01_scenario.png", alt: "面接シナリオ設計画面", title: "シナリオの作成", desc: "面接質問・合格点・評価基準を設定し、自社の一次面接をテンプレート化します。" },
    { num: "02", image: "service_02_interview.png", alt: "招待リンクからAI面接を実施する画面", title: "招待リンクで実施", desc: "候補者はURLから入室。ログイン不要で、AIが音声面接を進めます。" },
    { num: "03", image: "service_03_results.png", alt: "評価結果とフォローを可視化する画面", title: "結果とフォローの自動化", desc: "スコア・合否・回答ログを可視化し、次アクションまでつなげます。" }
  ].freeze

  SERVICE_CARDS_EN = [
    { num: "01", image: "service_01_scenario.png", alt: "Interview scenario design screen", title: "Build scenarios", desc: "Set questions, passing scores, and rubrics to template your first-round interviews." },
    { num: "02", image: "service_02_interview.png", alt: "AI interview via invite link", title: "Run via invite link", desc: "Candidates join from a URL. No login — AI runs the voice interview." },
    { num: "03", image: "service_03_results.png", alt: "Results and follow-up dashboard", title: "Automate results & follow-up", desc: "Surface scores, pass/fail, and logs — then connect next actions." }
  ].freeze

  COMPANY_PROFILE = [
    ["会社名", "株式会社J Work"],
    ["代表取締役", "奥山　健太"],
    ["設立", "2023年8月22日"],
    ["資本金", "5,000,000円"],
    ["所在地", "東京都港区浜松町２丁目２番１５号２Ｆ"],
    ["事業内容", "AI面接サービス「Recrivo」の開発・提供"]
  ].freeze

  COMPANY_PROFILE_EN = [
    ["Company", "J Work Inc."],
    ["CEO", "Kenta Okuyama"],
    ["Founded", "August 22, 2023"],
    ["Capital", "JPY 5,000,000"],
    ["Address", "2F, 2-2-15 Hamamatsucho, Minato-ku, Tokyo"],
    ["Business", "Development and delivery of Recrivo, an AI interview service"]
  ].freeze

  COMPANY_STATS = [
    { icon: "fa-face-smile", label: "顧客満足度", num: "97.5", unit: "%" },
    { icon: "fa-building", label: "取引実績", num: "500", unit: "+" },
    { icon: "fa-clock", label: "対応体制", num: "24", unit: "時間" }
  ].freeze

  COMPANY_STATS_EN = [
    { icon: "fa-face-smile", label: "Satisfaction", num: "97.5", unit: "%" },
    { icon: "fa-building", label: "Track record", num: "500", unit: "+" },
    { icon: "fa-clock", label: "Coverage", num: "24", unit: "h" }
  ].freeze

  COMPARE_ROWS = [
    { label: "初回対応", icon: "fa-bolt", legacy: "日程調整後に人が実施", meetia: "招待リンクですぐAI面接を開始" },
    { label: "対応時間", icon: "fa-clock", legacy: "担当者の稼働時間に依存", meetia: "24時間365日受験可能" },
    { label: "評価・記録", icon: "fa-chart-line", legacy: "メモが属人化", meetia: "スコア・合否・ログを自動保存" },
    { label: "評価の公平性", icon: "fa-scale-balanced", legacy: "面接官ごとに判定がばらつく", meetia: "同一シナリオで合否・スコアを統一" },
    { label: "運用工数", icon: "fa-users", legacy: "一次面接に人が張り付く", meetia: "AIが一次対応し、人は見極めに集中" }
  ].freeze

  COMPARE_ROWS_EN = [
    { label: "First response", icon: "fa-bolt", legacy: "People run it after scheduling", meetia: "AI interview starts from an invite link" },
    { label: "Availability", icon: "fa-clock", legacy: "Limited to staff hours", meetia: "Candidates can join 24/7/365" },
    { label: "Scoring & records", icon: "fa-chart-line", legacy: "Notes stay personal", meetia: "Scores, decisions, and logs auto-saved" },
    { label: "Fairness", icon: "fa-scale-balanced", legacy: "Outcomes vary by interviewer", meetia: "Same scenario, unified scores" },
    { label: "Ops effort", icon: "fa-users", legacy: "People stuck on first rounds", meetia: "AI handles first line; humans decide" }
  ].freeze

  FAQ_CATEGORIES = [
    ["service", "サービスについて", "fa-comments"],
    ["pricing", "料金・トライアル", "fa-yen-sign"],
    ["setup", "申し込み・開始", "fa-rocket"],
    ["usage", "使い方・運用", "fa-chart-line"]
  ].freeze

  FAQ_CATEGORIES_EN = [
    ["service", "Service", "fa-comments"],
    ["pricing", "Pricing & trial", "fa-yen-sign"],
    ["setup", "Signup & launch", "fa-rocket"],
    ["usage", "Usage", "fa-chart-line"]
  ].freeze

  TRIAL_FEATURES = [
    { icon: "fa-rocket", label: "即日スタート", desc: "シナリオを用意してリンクを送るだけで、すぐに体験できます。" },
    { icon: "fa-shield-halved", label: "セキュア設計", desc: "トークン認証と暗号化で、企業利用にも安心の環境を提供します。" },
    { icon: "fa-chart-simple", label: "成果を可視化", desc: "合否・スコア・回答ログをダッシュボードで確認できます。" }
  ].freeze

  TRIAL_FEATURES_EN = [
    { icon: "fa-rocket", label: "Start today", desc: "Prepare a scenario, send a link, and try it right away." },
    { icon: "fa-shield-halved", label: "Secure design", desc: "Token auth and encryption for business use." },
    { icon: "fa-chart-simple", label: "Visible results", desc: "Review pass/fail, scores, and logs on the dashboard." }
  ].freeze

  LP_COMPARISON_FEATURES_EN = [
    { key: :situation_limit, label: "Interview scenarios" },
    { key: :monthly_interview_limit, label: "Interviews / month" },
    { key: :voice_ai_interview, label: "AI voice interviews" },
    { key: :auto_scoring, label: "Auto scoring & pass/fail" },
    { key: :guest_invite, label: "Invite links (no login)" },
    { key: :result_dashboard, label: "Results dashboard" },
    { key: :follow_up_automation, label: "Follow-up automation" },
    { key: :priority_support, label: "Priority support" }
  ].freeze

  def lp_english?
    I18n.locale.to_s == "en"
  end

  def lp_nav_items
    lp_english? ? LP_NAV_ITEMS_EN : LP_NAV_ITEMS
  end

  def featured_columns_for_lp
    live = FeaturedColumnsLoader.call(limit: 5)
    return live if live.present?

    lp_english? ? FEATURED_COLUMNS_EN : FEATURED_COLUMNS
  end

  def hero_feature_cards
    lp_english? ? HERO_FEATURE_CARDS_EN : HERO_FEATURE_CARDS
  end

  def feature_rows
    lp_english? ? FEATURE_ROWS_EN : FEATURE_ROWS
  end

  def faq_items
    lp_english? ? FAQ_ITEMS_EN : FAQ_ITEMS
  end

  def review_cards
    lp_english? ? REVIEW_CARDS_EN : REVIEW_CARDS
  end

  def problem_items
    lp_english? ? PROBLEM_ITEMS_EN : PROBLEM_ITEMS
  end

  def service_cards
    lp_english? ? SERVICE_CARDS_EN : SERVICE_CARDS
  end

  def company_profile_rows
    lp_english? ? COMPANY_PROFILE_EN : COMPANY_PROFILE
  end

  def company_stats
    lp_english? ? COMPANY_STATS_EN : COMPANY_STATS
  end

  def compare_rows
    lp_english? ? COMPARE_ROWS_EN : COMPARE_ROWS
  end

  def faq_categories
    lp_english? ? FAQ_CATEGORIES_EN : FAQ_CATEGORIES
  end

  def trial_features
    lp_english? ? TRIAL_FEATURES_EN : TRIAL_FEATURES
  end

  def lp_comparison_features
    lp_english? ? LP_COMPARISON_FEATURES_EN : Subscription::LP_COMPARISON_FEATURES
  end

  def lp_plan_name(config)
    lp_english? ? (config[:name_en].presence || config[:name]) : config[:name]
  end

  def lp_plan_description(config)
    lp_english? ? (config[:description_en].presence || config[:description]) : config[:description]
  end

  def lp_plan_cta(config)
    default = t("recrivo.lp.pricing_default_cta")
    if lp_english?
      config[:lp_cta_en].presence || config[:lp_cta].presence || default
    else
      config[:lp_cta].presence || default
    end
  end

  def lp_plans_path
    lp_english? ? localized_plans_path(locale: :en) : plans_path
  end

  def lp_nav_active?(key)
    @lp_page == key.to_s
  end

  def lp_sign_up_path
    client_sign_up_path_for_locale
  end

  def lp_trial_experience_path
    if client_signed_in? || admin_signed_in?
      dashboard_root_path
    else
      client_sign_up_path_for_locale
    end
  end

  def lp_trial_experience_link_options
    {}
  end

  def lp_login_path
    if client_signed_in? || admin_signed_in?
      dashboard_root_path
    else
      client_sign_in_path_for_locale
    end
  end

  def lp_login_label
    if client_signed_in? || admin_signed_in?
      t("recrivo.lp.mypage")
    else
      t("recrivo.lp.login")
    end
  end
end
