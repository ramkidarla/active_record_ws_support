= active_record_ws_support

This adds some changes to ActiverRecord to make it work via web services with a new restful adapter. The ActiveRecord works as usual.

== Usage:

  Generic restfull url mappings:
  
      1) :model_name/select                   :via => :post    # Finder methods
                                                               # Request parameters: sql
                                                               # Response: 200 code -> json obj
      
      2) :model_name/valid                    :via => :post    # Validation
                                                               # Request parameters: id, attributes
                                                               # Response: 400 code -> json validtion errors                   
      
      3) :model_name/fields                   :via => :get     # Model columns and attributes
                                                               # Request parameters: id, attributes
                                                               # Response: 200 code -> json model columns map
     
      4) :model_name(.:format)                :via => :post    # model create
                                                               # Request parameters: attributes
                                                               # Response: 200 code -> json obj
                                                               #           400 code -> json validtion errors
      
      5) :model_name/:id(.:format)            :via => :get     # Get model details
                                                               # Request parameters: id
                                                               # Response: 200 code -> json obj
                                                               
      6) :model_name/:id(.:format)            :via => :put     # Model update
                                                               # Request parameters: id, attributes
                                                               # Response: 200 code -> head OK
                                                               #           400 code -> json validtion errors
      
      7) :model_name/:id(.:format)            :via => :delete  # Model Delete
                                                               # Request parameters: id
                                                               # Response: 200 code -> head OK
      
      8) :model_name/:operation/:id(.:format) :via => :post    # Invoke model business methods
                                                               # Request parameters: id, operation, attributes
                                                               # Response: 200 code -> json response
Setup:
 - Copy generic_controller file to your controllers directory.
 - Add the routes in config/routes.rb to your config/routes.rb file
