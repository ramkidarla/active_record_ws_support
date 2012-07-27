RedzoneSso::Application.routes.draw do

  namespace :api do
    namespace :v1 do
      match "data" => "data#show"
      
      match ':model_name(.:format)/select'                             => 'generic#select',  :via => :post,   :defaults => { :format => 'json' }
      match ':model_name(.:format)/valid'                              => 'generic#valid',   :via => :post,   :defaults => { :format => 'json' }
      match ':model_name(.:format)/fields'                             => 'generic#fields',  :via => :get,    :defaults => { :format => 'json' }
      match ':model_name(.:format)'                                    => 'generic#create',  :via => :post,   :defaults => { :format => 'json' }
      match ':model_name(.:format)/:id(.:format)'                      => 'generic#show',    :via => :get,    :defaults => { :format => 'json' }
      match ':model_name(.:format)/:id(.:format)'                      => 'generic#update',  :via => :put,    :defaults => { :format => 'json' }
      match ':model_name(.:format)/:id(.:format)'                      => 'generic#destroy', :via => :delete, :defaults => { :format => 'json' }
      match ':model_name(.:format)/:operation(.:format)/:id(.:format)' => 'generic#invoke',  :via => :post,   :defaults => { :format => 'json' }
      
      
    end
  end

end
