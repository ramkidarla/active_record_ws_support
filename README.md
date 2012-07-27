active_record_ws_support
========================

Usage:

To Work ActiveRecord via restfull webservice change as below in respective model.

    class User < ActiveRecord::Base
    
        establish_connection :adapter => 'restfull_json', 
                  :host => '192.168.11.8',
                  :use_ssl => false,
                  :hydra => HYDRA,
                  :use_api_key => true,
                  :api_key_name => 'access_token',
                  :api_key => "2MNFP7SrgD3QhuvuUY0hD2P8s7MSdCewHySAYvQo",
                  :resource_path => "/api/v1/users"
    
    end
    
==========================
Modifications
==========================

    - Added a new restfull adapter
    - Added a new persistance layer & validation layer modules
    