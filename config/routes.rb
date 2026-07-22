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
    passwords: "clients/passwords"
  }

  root to: 'tops#index'

  get 'whats', to: redirect('/#whats')
  get 'service', to: redirect('/#service')
  get 'features', to: redirect('/#features')
  get 'pricing', to: redirect('/#pricing')
  get 'faq', to: redirect('/#faq')
  get 'company', to: redirect('/#company')

  # 受験者向け面接ポータル
  get 'interview', to: 'tops#interview'
  get 'i/:token', to: 'tops#interview_invite', as: :interview_invite

  # 面接シナリオ管理（企業）
  resources :situations do
    resources :questions, except: [:show] do
      member do
        post :toggle_publish
      end
    end
    member do
      post :regenerate_invite_token
      post :suggest_questions
      post :apply_suggested_questions
    end
  end

  require 'sidekiq/web'
  authenticate :admin do
    mount Sidekiq::Web, at: "/sidekiq"
  end

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
      end
      collection do
        post :start
        post :start_by_token
      end
    end
  end

  get '/api/interviews/start', to: redirect('/interview')
  get '/api/interviews/start_by_token', to: redirect('/interview')

  namespace :admin do
    root to: redirect('/dashboard/index')
    resources :interview_results, only: [:index, :show]
    resources :notifications
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
    resources :notifications
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

  get 'checkout/confirmation', to: 'checkout#confirmation', as: :checkout_confirmation
  post 'checkout/create', to: 'checkout#create', as: :checkout_create
  get 'checkout/success', to: 'checkout#success', as: :checkout_success
  get 'checkout/cancel', to: 'checkout#cancel', as: :checkout_cancel

  get 'plans', to: 'plans#index', as: :plans
  post 'plans/select', to: 'plans#select', as: :select_plan

  post '/webhooks/stripe', to: 'webhooks#stripe'
end
