Rails.application.routes.draw do
  get 'messages/reply'
  
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions',  # Add other controllers if needed
    passwords: 'users/passwords' # Example for password resets
  }
  
  resources :users
  
  resources :dispatches do 
    member do
      post 'send_notification'
    end
  end
  
  resources :locations do
    resources :location_products, only: [:new, :create, :edit, :update, :destroy]
  end
  
  resources :customers
  resources :customer_orders
  
  resource :messages do
    collection do
      post 'reply'
    end
  end
  
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

