Rails.application.routes.draw do
  # Batch QR label routes — BatchController uses its own session gate, not Devise
  get  '/gate',          to: 'batch#gate',          as: :gate
  post '/gate',          to: 'batch#authenticate'
  get  '/labels',        to: 'batch#new',            as: :labels
  post '/labels/encode', to: 'batch#encode',         as: :labels_encode
  get  '/l',             to: 'batch#show',           as: :label

  #get 'assets/index'
  #get 'assets/show'
  get 'warehouse/kanban', to: 'warehouse#kanban', as: :warehouse_kanban
  get 'calendar', to: 'calendar#index'
  get 'calendar/events', to: 'calendar#events'
  get 'vendors/index'
  get 'vendors/new'
  get 'vendors/create'
  get 'vendors/destroy'
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
      patch :mark_as_sent_to_driver
      post :upload_files
    end
    collection do
      get 'kanban'
      get :export_csv
    end
  end
  
  get 'locations/map', to: 'locations#map', as: :locations_map
  get 'locations/vehicles', to: 'locations#vehicles', as: :locations_vehicles
  get 'locations/dispatch_routes', to: 'locations#dispatch_routes', as: :locations_dispatch_routes
  resources :locations do
    resources :location_products, only: [:new, :create, :edit, :update, :destroy]
    collection do
      get :search
      get :select2
    end
    member do
      patch :toggle_status
    end
  end
  
  resources :customers do
    collection do
      get :search
      get :select2
    end
  end
  
  resources :quotes do
    member do
      post :send_quote
      post :accept
      post :reject
    end
  end

  resources :customer_orders do
    post 'create_dispatch', on: :member
    resources :customer_order_products, only: [:create, :update, :destroy]
    collection do
      get :dashboard
    end
  end

  get  'product_code_links',        to: 'customer_order_products#unlinked',   as: :product_code_links
  post 'product_code_links/update', to: 'customer_order_products#link_codes', as: :link_product_codes
  
  resource :messages do
    collection do
      post 'reply'
    end
  end

  resources :work_orders do
    collection do
      get :workables
    end
    member do
      patch :change_status
    end
    resources :comments, only: :create
  end

  resources :production_orders do
    collection do
      get :kanban
      get :dashboard
    end
  end


  get 'mrp', to: 'mrp#index', as: :mrp
  get 'docs',                  to: 'docs#index',         as: :docs
  get 'docs/dispatch-guide',   to: 'docs#dispatch_guide', as: :docs_dispatch
  get 'docs/manufacturing',    to: 'docs#manufacturing',  as: :docs_manufacturing
  get 'docs/mrp-guide',        to: 'docs#mrp_guide',     as: :docs_mrp_guide
  get 'docs/changelog',        to: 'docs#changelog',     as: :docs_changelog

  resources :purchase_orders, only: [:index, :new, :create, :show] do
    member do
      patch :approve
      patch :submit
      patch :receive
      patch :post_to_inventory
    end
    collection do
      get :export_pdi
    end
  end

  resource :purchase_order_imports, only: [:new, :create] do
    collection do
      post :preview
    end
  end
  get 'purchase_order_imports/download/:log_id', to: 'purchase_order_imports#download', as: :download_purchase_order_import

  resources :production_order_batches, only: [] do
    member do
      patch :update_qc
      patch :complete
    end
  end

  resources :inventory_adjustments, only: [:new, :create]
  resources :inventory_transactions, only: [:index]
  resource :inventory_import, only: [:new, :create] do
    post :preview, on: :collection
  end
  resource :bom_import, only: [:new, :create] do
    post :preview, on: :collection
  end
  get 'bom_import/download/:log_id', to: 'bom_imports#download', as: :download_bom_import

  resource :min_max_import, only: [:new, :create] do
    post :preview, on: :collection
  end
  get 'min_max_import/download/:log_id', to: 'min_max_imports#download', as: :download_min_max_import

  resource :warehouse_transaction_import, only: [:new, :create] do
    post :preview, on: :collection
  end
  get 'warehouse_transaction_import/download/:log_id', to: 'warehouse_transaction_imports#download', as: :download_warehouse_transaction_import

  resource :customer_order_import, only: [:new, :create] do
    post :preview, on: :collection
  end
  get 'customer_order_import/download/:log_id', to: 'customer_order_imports#download', as: :download_customer_order_import

  resources :things

  resources :announcements

  resources :products, format: false do
    collection do
      get :search
    end
    member do
      get :bom
    end
  end

  resources :dispatch_messages, only: [:index, :show]

  resources :vendors, only: [:index, :new, :create, :destroy, :show, :edit, :update]

  resources :automated_processes, only: [:index, :show], param: :id do
    member do
      post  :trigger
      patch :update_config
      get   'download/:log_id', action: :download_file, as: :download_file
    end
  end

  delete 'dispatches/:dispatch_id/files/:id', to: 'dispatches#destroy_file', as: 'dispatch_file'

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

