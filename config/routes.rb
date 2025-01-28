Rails.application.routes.draw do
  get 'messages/reply'

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions', 
    passwords: 'users/passwords'
  }
  
  resources :users

  resources :dispatches do 
    member do
      post 'send_notification'
      patch :mark_as_complete
      patch :mark_as_billed
    end
  end
  
  get 'locations/map', to: 'locations#map', as: :locations_map
  resources :locations do
    resources :location_products, only: [:new, :create, :edit, :update, :destroy]
    collection do
      get :search
    end
  end
  
  resources :customers do
    collection do
      get :search
    end
  end
  
  resources :customer_orders do
    post 'create_dispatch', on: :member
    resources :customer_order_products, only: [:create, :update, :destroy]
  end
  
  resource :messages do
    collection do
      post 'reply'
    end
  end

  resources :products

  resources :dispatch_messages, only: [:index, :show]

  resources :phone_numbers, only: [:destroy]
  
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

