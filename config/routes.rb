Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  devise_for :admins, skip: [:registrations], controllers: {
    sessions: "admins/sessions",
    passwords: "admins/passwords"
  }

  devise_for :clients, controllers: {
    sessions: "clients/sessions",
    registrations: "clients/registrations",
    passwords: "clients/passwords",
    omniauth_callbacks: "clients/omniauth_callbacks"
  }

  get "locale/:locale", to: "locales#update", as: :switch_locale, constraints: { locale: /ja|en/ }

  # --- Public marketing pages: / = ja, /en/... = English ---
  scope "/:locale", constraints: { locale: /en/ } do
    get "/", to: "tops#index", as: :localized_root
    get "plans", to: "plans#index", as: :localized_plans
    post "plans/select", to: "plans#select", as: :localized_select_plan
    get "whats", to: redirect { |path_params, _req| "/#{path_params[:locale]}#whats" }
    get "service", to: redirect { |path_params, _req| "/#{path_params[:locale]}#service" }
    get "features", to: redirect { |path_params, _req| "/#{path_params[:locale]}#features" }
    get "pricing", to: redirect { |path_params, _req| "/#{path_params[:locale]}#pricing" }
    get "reviews", to: redirect { |path_params, _req| "/#{path_params[:locale]}#reviews" }
    get "faq", to: redirect { |path_params, _req| "/#{path_params[:locale]}#faq" }
    get "company", to: redirect { |path_params, _req| "/#{path_params[:locale]}#company" }

    devise_scope :client do
      get "clients/sign_in", to: "clients/sessions#new", as: :new_client_session_en
      post "clients/sign_in", to: "clients/sessions#create", as: :client_session_en
      delete "clients/sign_out", to: "clients/sessions#destroy", as: :destroy_client_session_en
      get "clients/sign_up", to: "clients/registrations#new", as: :new_client_registration_en
      post "clients", to: "clients/registrations#create", as: :client_registration_en
      get "clients/password/new", to: "clients/passwords#new", as: :new_client_password_en
      get "clients/password/edit", to: "clients/passwords#edit", as: :edit_client_password_en
      post "clients/password", to: "clients/passwords#create", as: :client_password_en
      put "clients/password", to: "clients/passwords#update"
      patch "clients/password", to: "clients/passwords#update"
    end
  end

  root to: 'tops#index'

  get 'whats', to: redirect('/#whats')
  get 'service', to: redirect('/#service')
  get 'features', to: redirect('/#features')
  get 'pricing', to: redirect('/#pricing')
  get 'reviews', to: redirect('/#reviews')
  get 'faq', to: redirect('/#faq')
  get 'company', to: redirect('/#company')

  # 受験者向け面接ポータル
  get 'interview', to: 'tops#interview'
  get 'i/:token', to: 'tops#interview_invite', as: :interview_invite

  namespace :api do
    resources :interviews, only: [] do
      member do
        get :next_question
        post :submit_answer
        post :answer, action: :submit_answer
        post :transcribe
        post :complete
        get :status
        post :resume
        post :track_event
        post :evaluate
        get :faqs
      end
      collection do
        post :start
        post :start_by_token
      end
    end
  end

  get '/api/interviews/start', to: redirect('/interview')
  get '/api/interviews/start_by_token', to: redirect('/interview')

  get 'follow_up/o/:token', to: 'public/follow_up_tracking#open', as: :follow_up_open
  get 'follow_up/c/:token', to: 'public/follow_up_tracking#click', as: :follow_up_click
  get 'follow_up/unsubscribe/:token', to: 'public/follow_up_tracking#unsubscribe', as: :follow_up_unsubscribe

  namespace :admin do
    root to: redirect('/dashboard/index')
    resources :interview_results, only: [:index, :show]
  end

  namespace :dashboard do
    get 'index', to: 'dashboard#index', as: :index
    root to: 'dashboard#index'

    resource :account, only: [:show, :update]
    get "management", to: "management#index", as: :management
    resource :subscription, only: [:show, :update] do
      get :cancel_confirm
      post :cancel
    end
    resources :notifications, only: [:index, :show, :update] do
      collection do
        post :mark_all_read
      end
    end
    resources :candidates, only: [:index, :show] do
      member do
        patch :update_ops_status
      end
    end
    resources :interview_results, only: [:index, :show] do
      member do
        post :notify_hire
        post :notify_reject
        post :regenerate_summary
        post :judge_pass
        post :judge_fail
      end
    end
  end

  resources :situations do
    resources :questions, except: [:show] do
      member do
        post :toggle_publish
      end
    end
    resources :situation_faqs, only: [:create, :update, :destroy], controller: "situation_faqs"
    member do
      post :regenerate_invite_token
      post :suggest_questions
      post :apply_suggested_questions
      patch :update_candidate_registration
      patch :update_follow_up_settings
      post :upload_recruitment_material
      delete :remove_recruitment_material
    end
  end

  require 'sidekiq/web'
  authenticate :admin do
    mount Sidekiq::Web, at: "/sidekiq"
  end

  resources :problems

  get 'checkout/confirmation', to: 'checkout#confirmation', as: :checkout_confirmation
  post 'checkout/create', to: 'checkout#create', as: :checkout_create
  get 'checkout/success', to: 'checkout#success', as: :checkout_success
  get 'checkout/cancel', to: 'checkout#cancel', as: :checkout_cancel

  get 'plans', to: 'plans#index', as: :plans
  post 'plans/select', to: 'plans#select', as: :select_plan

  post '/webhooks/stripe', to: 'webhooks#stripe'
end
