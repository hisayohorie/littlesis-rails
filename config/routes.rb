Lilsis::Application.routes.draw do
  # match "*path", to: "errors#maintenance", via: :all

  mount Bootsy::Engine => '/bootsy', as: 'bootsy'

  #         new_user_session GET    /users/sign_in(.:format)                          users/sessions#new
  #             user_session POST   /users/sign_in(.:format)                          users/sessions#create
  #     destroy_user_session GET    /users/sign_out(.:format)                         users/sessions#destroy
  #            user_password POST   /users/password(.:format)                         devise/passwords#create
  #        new_user_password GET    /users/password/new(.:format)                     devise/passwords#new
  #       edit_user_password GET    /users/password/edit(.:format)                    devise/passwords#edit
  #                          PATCH  /users/password(.:format)                         devise/passwords#update
  #                          PUT    /users/password(.:format)                         devise/passwords#update
  # cancel_user_registration GET    /users/cancel(.:format)                           users/registrations#cancel
  #        user_registration POST   /users(.:format)                                  users/registrations#create
  #    new_user_registration GET    /users/sign_up(.:format)                          users/registrations#new
  #   edit_user_registration GET    /users/edit(.:format)                             users/registrations#edit
  #                          PATCH  /users(.:format)                                  users/registrations#update
  #                          PUT    /users(.:format)                                  users/registrations#update
  #                          DELETE /users(.:format)                                  users/registrations#destroy
  #        user_confirmation POST   /users/confirmation(.:format)                     users/confirmations#create
  #    new_user_confirmation GET    /users/confirmation/new(.:format)                 users/confirmations#new
  #                          GET    /users/confirmation(.:format)                     users/confirmations#show

  devise_for :users, controllers: { confirmations: 'users/confirmations'  }, :skip => [:sessions, :registrations]
  as :user do
    get '/login' => 'users/sessions#new', :as => :new_user_session
    post '/login' => 'users/sessions#create', :as => :user_session
    get '/logout' => 'users/sessions#destroy', :as => :destroy_user_session
    get '/join' => 'users/registrations#new', :as => :new_user_registration
    post '/join' => 'users/registrations#create', :as => :user_registration
    get '/users/cancel' => 'users/registrations#cancel', :as => :cancel_user_registration
    get '/users/edit' => 'users/registrations#edit', :as => :edit_user_registration
    patch '/users' => 'users/registrations#update'
    put '/users' => 'users/registrations#update'
    delete '/users' => 'users/registrations#destroy'
  end

  get '/join/success' => 'users#success'

  root to: 'home#index'
  get '/home' => 'home#index'
  get '/contact' => 'home#contact'
  post '/contact' => 'home#contact'

  get "/admin" => "admin#home"
  post "/admin/clear_cache" => "admin#clear_cache"

  resources :hubs, controller: 'campaigns', as: 'campaigns' do
    member do
      get 'search_groups'
      get 'groups'
      get 'admin'
      post 'clear_cache'
      get 'entities'
      get 'edit_findings'
      get 'edit_guide'
      get 'signup'
      post 'subscribe'
      get 'thankyou'
    end
  end

  get '/hubs/:id(/:campaign_tabs_selected_tab)' => 'campaigns#show'

  resources :groups do
    member do
      get 'notes'
      get 'edits'
      get 'lists'
      post 'remove_list'
      post 'feature_list'
      post 'unfeature_list'
      get 'new_list'
      post 'add_list'
      post 'join'
      post 'leave'
      get 'users'
      post 'promote_user'
      post 'demote_user'
      post 'remove_user'
      get 'admin'
      get 'entities'
      post 'clear_cache'
      get 'edit_findings'
      get 'edit_howto'
      get 'edit_advanced'
    end

    collection do
      get 'request_new'
      post 'send_request'
      get 'request_sent'
    end
  end

  get '/groups/:id(/:group_tabs_selected_tab)' => 'groups#show'

  resources :users, only: [:index] do
    member do 
      get 'edit_permissions' 
      post 'add_permission'
      delete 'delete_permission'
      delete 'destroy'
    end
    collection do
      get 'admin'
    end
  end

  resources :lists, only: [:index, :edit, :update, :new, :create, :show] do
    member do
      get 'relationships'
      get 'match_donations'
      get 'admin'
      get 'find_articles'
      get 'crop_images'
      get 'street_views'
      get 'members'
      post 'create_map'
      post 'update_entity'
      post 'remove_entity'
      get 'clear_cache'
      post 'add_entity'
      post 'delete'
      get 'interlocks'
      get 'companies'
      get 'government'
      get 'other_orgs'
      get 'references'
      get 'giving'
      get 'funding'
      get 'modifications'
    end
  end

  resources :images do
    member do
      get 'crop'
      post 'crop_remote'
    end
  end

  resources :entities do
    member do
      get 'relationships'
      get 'political'
      get 'match_donations'
      get 'match_ny_donations'
      get 'review_donations'
      get 'review_ny_donations'
      post 'match_donation'
      post 'unmatch_donation'
      get 'contributions'
      get 'potential_contributions'
      get 'edit_twitter'
      post 'add_twitter'  
      post 'remove_twitter'
      get 'fields'
      post 'update_fields'
      get 'articles'
      get 'find_articles'
      post 'import_articles'
      post 'remove_article'
      get 'new_article'
      post 'create_article'
      get 'find_merges'
      post 'merge'
      get 'refresh'
      get 'images'
      get 'new_image'
      post 'upload_image'
      post 'remove_image'
      post 'feature_image'
      get 'add_relationship'
    end

    collection do
      get 'search_by_name', as: 'name_search'
      get 'search_field_names', as: 'field_name_search'
      get 'next_twitter'
    end
  end

  resources :notes, only: [:new, :create, :destroy, :index]

  get "/notes/:username",
    controller: 'notes',
    action: 'user',
    constraints: { username: /[\w.]+/ },
    as: "user_notes"
  get "/notes/:username/:id",
    controller: 'notes',
    action: 'show',
    constraints: { username: /[\w.]+/, id: /\d+/ },
    as: "note_with_user"

  get "/story_maps/:id", 
    controller: 'story_maps',
    action: 'story_map',
    as: "story_map"

  resources :maps do
    member do
      get 'raw'
      get 'capture'
      get 'edit_meta'
      post 'update_meta'
      post 'clone'
      get 'edit_fullscreen'
      get 'annotations'
      get 'new_annotation'
      post 'create_annotation'
      post 'update_annotation'
      get 'edit_annotation'
      post 'reorder_annotations'
      post 'destroy_annotation'
      get 'collection'
      get 'embedded'
      get 'map_json'
      get 'dev'
      get 'edit/dev'  => "maps#dev_edit"
    end

    collection do
      get 'search'
      get 'featured'
      get 'find_nodes'
      get 'node_with_edges'
      get 'edges_with_nodes'
      get 'interlocks'
    end
  end


  get "/maps/:id/:slide",
    controller: 'maps',
    action: 'show',
    as: 'map_slide'

  get "/maps/:id/share/:secret",
    controller: 'maps',
    action: 'show',
    as: 'share_map'

  resources :topics do
    member do
      get 'new_elements'      
      post 'add_elements'
      post 'remove_element'
      get 'map_collections'
    end
  end

  resources :industries, only: [:show]

  resources :relationships, only: [:show, :create]

  resources :references, only: [:create, :destroy]
  get "/references/recent" => "references#recent"
  

  get "/search" => "search#basic"
  get "/search/entity" => "search#entity_search"

  get "/home/notes" => "home#notes"
  get "/home/groups" => "home#groups"
  get "/home/maps" => "home#maps"
  get "/home/dashboard" => "home#dashboard"
  post "/home/dismiss",
    controller: 'home',
    action: 'dismiss',
    as: 'dismiss_helper'

  # get "/entities/search_by_name",
  #   controller: 'entities',
  #   action: 'search_by_name',
  #   as: 'entity_name_search'

  get "/edits" => "edits#index"
  get "/oligrapher" => "maps#splash"
  get "/graph" => "graph#all"
    
  ##########
  #  pages #
  ##########

  get "/partypolitics" => "pages#partypolitics"
  get "/regime" => "pages#regime"

  ####### 
  # NYS #
  ####### 
  
  post "/nys/match_donations" => "nys#match_donations"
  get "/nys/candidates" => "nys#candidates"
  get "/nys/candidates/new" =>  "nys#new_filer_entity"
  post "/nys/candidates/new" =>  "nys#create"
  get "/nys/potential_contributions" => "nys#potential_contributions"
  get "/nys/contributions" => "nys#contributions"

  match "*path", to: "errors#not_found", via: :all

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root to: 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
