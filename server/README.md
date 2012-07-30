active_record_ws_support
========================
This adds some changes to ActiverRecord to make it work via web services with a new restful adapter. The ActiveRecord works as usual.

Usage:
  Generic restfull action:
  
      1) :model_name(.:format)/select                               :via => :post    # finder methods
      2) :model_name(.:format)/valid                                :via => :post    # validation
      3) :model_name(.:format)/fields                               :via => :get     # model attributes
      4) :model_name(.:format)                                      :via => :post    # model create
      5) :model_name(.:format)/:id(.:format)                        :via => :get     # get model
      6) :model_name(.:format)/:id(.:format)                        :via => :put     # model update
      7) :model_name(.:format)/:id(.:format)                        :via => :delete  # model delete
      8) :model_name(.:format)/:operation(.:format)/:id(.:format)   :via => :post    # Invoke model business methods
      
Setup:
 - Copy generic_controller file to your controllers directory.
 - Add the routes in config/routes.rb to your config/routes.rb file
