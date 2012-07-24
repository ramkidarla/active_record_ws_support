active_record_ws_support
========================

Usage:

 - To Work ActiveRecord via restfull webservice change as below in respective model.

	    class User < ActiveRecord::Base
	    
	        establish_connection :adapter => "restfull_json"
	    
	    end
	    
 - Add a restfull.yml under config and looks like below
 
		host: 127.0.0.1:3010
		use_ssl: false
		use_api_key: true
		api_key_name: access_token
		api_key: 2MNFP7SrgD3QhuvuUY0hD2P8s7MSdCewHySAYvQo
		resource_path: /api/v1/generic
		
 - Requires typhoeus, constantinople gems

    
==========================
Modifications
==========================

    - Added a new restfull adapter
    - Added a new persistance layer & validation layer modules
    