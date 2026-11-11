Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # --- Web app (Hotwire) -------------------------------------------------------------
  root "today#show"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :tasks, only: %i[index show create edit update destroy] do
    member do
      post :toggle
    end
  end
  resource :calendar, only: :show, controller: "calendar_view"
  resources :events, only: %i[new create edit update destroy]

  resource :settings, only: :show
  namespace :settings do
    resources :api_keys, only: %i[create destroy]
    resources :connected_apps, only: :destroy
    resource :feed_token, only: :create
    resources :calendars, only: %i[create update destroy]
    resources :projects, only: %i[create update destroy]
  end

  # --- REST API ----------------------------------------------------------------------
  namespace :api do
    namespace :v1 do
      resources :tasks, only: %i[index show create update destroy] do
        member do
          post :complete
          post :reopen
          post :schedule
        end
      end
      resources :projects, only: %i[index create update destroy]
      resources :events, only: %i[index show create update destroy]
      resources :calendars, only: %i[index create update destroy]
      get "agenda", to: "agenda#show"
      get "free_time", to: "agenda#free_time"
      get "connection", to: "connection#show"
      get "modules", to: "connection#modules"
    end
  end

  # --- Calendar feed (secret URL) -------------------------------------------------------
  get "feed/:token", to: "feeds#show", as: :feed, constraints: { token: /[A-Za-z0-9_\-]+/ }, format: :ics

  # --- MCP endpoint for Claude -----------------------------------------------------------
  match "mcp", to: "mcp#handle", via: %i[get post delete]

  # --- OAuth 2.1 (lets claude.ai custom connectors sign in) -----------------------------
  get ".well-known/oauth-protected-resource(/*resource)", to: "oauth/metadata#protected_resource"
  get ".well-known/oauth-authorization-server(/*issuer)", to: "oauth/metadata#authorization_server"
  get ".well-known/openid-configuration", to: "oauth/metadata#authorization_server"
  post "oauth/register", to: "oauth/registrations#create"
  get "oauth/authorize", to: "oauth/authorizations#new"
  post "oauth/authorize", to: "oauth/authorizations#create"
  post "oauth/token", to: "oauth/tokens#create"
  post "oauth/revoke", to: "oauth/tokens#revoke"
end
