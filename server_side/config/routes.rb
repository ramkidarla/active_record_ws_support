RedzoneSso::Application.routes.draw do

# Add below routes to your routes.rb
  namespace :api do
    namespace :v1 do
      match "data" => "data#show"
      resources :generic, :defaults => { :format => 'json' } do
        collection do
          get :schema_fields
          post :select
          post :valid
        end
      end
    end
  end

end
