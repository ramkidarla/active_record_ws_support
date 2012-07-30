active_record_ws_support
========================
This adds some changes to ActiverRecord to make it work via web services with a new restful adapter. The ActiveRecord works as usual.

Usage:

 - with ActiveRecord

  	class User < ActiveRecord::Base
    
    end 
 
 - with active_record_ws_support

		class User < ActiveRecord::Base
		  establish_connection :adapter => 'restfull_json', 
              :remote_ws_url => Settings.api.sso.remote_ws_url,
              :api_key_name => Settings.api.sso.api_key_name,
              :api_key => Settings.api.sso.api_key,
              :remote_model => "users"
		end
	    
Setup:
 - Copy the whole active_record folder to lib under the root.
 - Update api.yml file under config directory with content similar to below
 
		remote_ws_url: http://127.0.0.1:2000/api/v1/
		api_key_name: access_token
		api_key: 2MNFP7SrgD3QhuvuUY0hD2P8s7MSdCewHySAYvQo
		

Note: 
		Works with rails-3.2.6 and ruby-1.9.3

=========================
Dependencies
=========================

- typhoeus
- constantinople
  
    
==========================
Changelog on ActiveRecord
==========================

  - Added a new restfull adapter
  - Added a new persistance layer & validation layer modules
    