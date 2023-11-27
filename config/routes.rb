Rails.application.routes.draw do
  devise_for :users
  resources :users
  resources :dispatches
  resources :locations
  resources :customer_orders
  delete '/dispatches/:id', to: 'dispatches#destroy', as: 'destroy_dispatch'
  get '/view_dispatches', to: 'dispatches#view_dispatches', as: 'view_dispatches'
  get '/search', to: 'customer_orders#search', as: 'search'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

devise_scope :user do
    authenticated :user do
      root to: 'dispatches#index', as: :authenticated_root
    end

    unauthenticated do
      root to: 'devise/sessions#new', as: :unauthenticated_root
    end
  end
end
