active_record_ws_support
=========================
This adds some changes to ActiverRecord to make it work via web services with a new restful adapter. The ActiveRecord works as usual.

Usage:
=========
  Generic restfull url mapping:
  
      1) :model_name/select                   :via => :post    # Find records
                                                               # Request params: sql
                                                               # Response: status -> 200, data -> json, containing the selected records
      
      2) :model_name/valid                    :via => :post    # Check valid?
                                                               # Request params: id, attributes
                                                               # Response: status -> 400, data -> json, containing validtion errors                   
      
      3) :model_name/fields                   :via => :get     # Get attributes
                                                               # Request parameters: id, attributes
                                                               # Response: status -> 200, data -> json, containing all model attributes
     
      4) :model_name(.:format)                :via => :post    # Create a record
                                                               # Request params: attributes
                                                               # Response: status -> 200, data -> json, containing created record
                                                               #           status -> 400, data -> json, containing validtion errors
      
      5) :model_name/:id(.:format)            :via => :get     # Get a record
                                                               # Request parameters: id
                                                               # Response: status ->200, data -> json, containing the selected record
                                                               
      6) :model_name/:id(.:format)            :via => :put     # Update a record
                                                               # Request params: id, attributes
                                                               # Response: status -> 200, head OK
                                                               #           status -> 400, data -> json containing validtion errors
      
      7) :model_name/:id(.:format)            :via => :delete  # Delete a record
                                                               # Request params: id
                                                               # Response: status -> 200, head OK
      
      8) :model_name/:operation/:id(.:format) :via => :post    # Invoke model business methods
                                                               # Request params: id, operation, attributes
                                                               # Response: status -> 200, data -> json containing result of method
Setup:
==========
 - Copy generic_controller file to your controllers directory.
 - Add the routes in config/routes.rb to your config/routes.rb file
