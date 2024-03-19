Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "/generate_delivery", to: "reports#generate_delivery"
  get "/generate_pickup", to: "reports#generate_pickup"
  get "/generate_ups", to: "reports#generate_ups"
  get "/generate_summary", to: "reports#generate_summary"
  get "/generate_jobs", to: "reports#generate_jobs"

  resources :reports

  post "/webhooks/create", to: "webhooks#create"
  post "/webhooks/edit", to: "webhooks#edit"
  post "/webhooks/update", to: "webhooks#update"

  # Defines the root path route ("/")
  root "reports#index"
end
