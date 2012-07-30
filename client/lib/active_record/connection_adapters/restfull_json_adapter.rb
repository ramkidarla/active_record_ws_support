require 'active_record/connection_adapters/abstract/database_statements'
require 'arel/visitors/bind_visitor'

require 'date'
require 'bigdecimal'
require 'bigdecimal/util'
require 'active_support/core_ext/benchmark'
require 'active_support/deprecation'
require 'active_record/connection_adapters/schema_cache'
require 'monitor'

require 'timeout'
require 'typhoeus'
require 'logger'
require 'kaminari'


module ActiveRecord
  $HYDRA = Typhoeus::Hydra.new
  class Base
    attr_accessor :ws_errors
    # restfull json adapter
    def self.restfull_json_connection(config) # :nodoc:
      config = config.symbolize_keys
      ConnectionAdapters::RestfullJsonAdapter.new(config, logger)
    end

    include ActiveRecord::PersistenceLayer
    include ActiveRecord::ValidationsLayer
  end
  
 
  module Sanitization
    module ClassMethods
      def sanitize_attributes_hash_for_assignment(assignments)
        case assignments
          when Array; sanitize_attributes_hash_array(assignments)
          else        assignments
        end
      end
      
      def sanitize_attributes_hash_array(ary)
        statement, *values = ary
        
        attribute_with_values = {}
        (
        if values.first.is_a?(Hash) && statement =~ /:\w+/
          replace_named_bind_variables(statement, values.first)
        elsif statement.include?('?')
          replace_bind_variables(statement, values)
        elsif statement.blank?
          statement
        else
          statement % values.collect { |value| connection.quote_string(value.to_s) }
        end
        ).split(',').collect do |attr_v|  
            attr, val = attr_v.split('=')
            attribute_with_values[attr.strip.to_sym] = val.strip.gsub('\''){''}.to_sym.to_s
        end
        attribute_with_values
      end
    end
  end
   
  
  class Relation
    def insert(values, record = nil)
      return super(values) unless @klass.connection.adapter_name == 'RestfullJson'

      primary_key_value = nil
      if primary_key && Hash === values
        primary_key_value = values[values.keys.find { |k|
          k.to_s == primary_key
        }]
      end

      conn = @klass.connection

      substitutes = values.sort_by { |arel_attr,_| arel_attr.to_s }
      binds       = substitutes.map do |arel_attr, value|
        [@klass.columns_hash[arel_attr.to_s], value]
      end

      conn.record = record
      conn.exec_insert_call(primary_key_value, values)
    end

    def update_all(updates, conditions = nil, options = {})
      IdentityMap.repository[symbolized_base_class].clear if IdentityMap.enabled?
      if conditions || options.present?
        where(conditions).apply_finder_options(options.slice(:limit, :order)).update_all(updates)
      else
        if @klass.connection.adapter_name == 'RestfullJson'
          attributes_with_values = @klass.send(:sanitize_attributes_hash_for_assignment, updates)
          affected_rows = 0
          to_a.each {|object|
            flag = object.update_attributes(attributes_with_values)
            affected_rows = affected_rows + 1 if flag
            raise ActiveRecord::WsRecordInvalid.new(object) unless flag
          }.tap { reset }

        affected_rows
        else
          stmt = Arel::UpdateManager.new(arel.engine)

          stmt.set Arel.sql(@klass.send(:sanitize_sql_for_assignment, updates))
          stmt.table(table)
          stmt.key = table[primary_key]

          if joins_values.any?
            @klass.connection.join_to_update(stmt, arel)
          else
            stmt.take(arel.limit)
            stmt.order(*arel.orders)
            stmt.wheres = arel.constraints
          end

          @klass.connection.update stmt, 'SQL', bind_values
        end
      end
    end

    def delete_all(conditions = nil)
      IdentityMap.repository[symbolized_base_class] = {} if IdentityMap.enabled?
      if conditions
        where(conditions).delete_all
      else
        if @klass.connection.adapter_name == 'RestfullJson'
          to_a.each do |object|
            begin
              @klass.connection.record = object
              @klass.connection.exec_delete_call(object.id)
            rescue ActiveRecord::WsRecordInvalid => exception
              raise exception
            end
          end
          affected_rows = to_a.count

          reset
        affected_rows
        else
          statement = arel.compile_delete
          affected = @klass.connection.delete(statement, 'SQL', bind_values)

          reset
        affected
        end
      end
    end
  end
  
  
  
  module AttributeMethods #:nodoc:
    def attributes_with_values(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
      attrs      = {}
      klass      = self.class
      
      attribute_names.each do |name|
        if (column = column_for_attribute(name)) && (include_primary_key || !column.primary)

          if include_readonly_attributes || !self.class.readonly_attributes.include?(name)
            value = if klass.serialized_attributes.include?(name)
                      @attributes[name].serialized_value
                    else
                      read_attribute(name)
                    end
            attrs[name.to_sym] = value
          end
        end
      end
      
      attrs
    end
  end
  
  class WsRecordInvalid < ActiveRecordError
    attr_reader :record
    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(", ")
      super(I18n.t("activerecord.errors.messages.record_invalid", :errors => errors))
    end
  end  
  
  module ConnectionAdapters #:nodoc:
    extend ActiveSupport::Autoload
    
    autoload :Column

    autoload_under 'RestfullJson' do
      autoload :IndexDefinition,  'active_record/connection_adapters/abstract/schema_definitions'
      autoload :ColumnDefinition, 'active_record/connection_adapters/abstract/schema_definitions'
      autoload :TableDefinition,  'active_record/connection_adapters/abstract/schema_definitions'
      autoload :Table,            'active_record/connection_adapters/abstract/schema_definitions'

      autoload :SchemaStatements
      autoload :DatabaseStatements
      autoload :DatabaseLimits
      autoload :Quoting

      autoload :ConnectionPool
      autoload :ConnectionHandler,       'active_record/connection_adapters/abstract/connection_pool'
      autoload :ConnectionManagement,    'active_record/connection_adapters/abstract/connection_pool'
      autoload :ConnectionSpecification

      autoload :QueryCache
    end
    
    class RestfullJsonColumn < Column #:nodoc:
      class << self
        def binary_to_string(value)
          if value.encoding != Encoding::ASCII_8BIT
            value = value.force_encoding(Encoding::ASCII_8BIT)
          end
          value
        end
      end
    end

    # The Restfull adapter works Restfull JSON format
    
    # Options:
    #
    # * <tt>:database</tt> - Path to the database file.
    class RestfullJsonAdapter
      include Quoting, DatabaseStatements, SchemaStatements
      include DatabaseLimits
      include QueryCache
      include ActiveSupport::Callbacks
      include MonitorMixin
      
      define_callbacks :checkout, :checkin
      attr_accessor :last_insert_row_id
      
      
      attr_accessor :visitor, :pool, :record
      attr_reader :schema_cache, :last_use, :in_use, :logger
      alias :in_use? :in_use
      
      attr_accessor :remote_ws_url, :remote_model, :api_key, :api_key_name, :timeout, :log_path
     
     
      def timeout; @timeout ||= DEFAULT_TIMEOUT; end
      def log_path; "log/active_record_restfull_json.log"; end
      def use_api_key; api_key_name.present?; end
      
                     
      
      DEFAULT_TIMEOUT = 10000
      
      
      def resource_uri(action = nil)
        sufix = (action.nil?)? "" : "/#{action}"
        "#{remote_ws_url}#{remote_model}#{sufix}"
      end
      
    
      ADAPTER_NAME = 'RestfullJson'
      
      def adapter_name
        ADAPTER_NAME
      end
      
      
      class BindSubstitution <  Arel::Visitors::ToSql
        include Arel::Visitors::BindVisitor
      end
      
      def initialize(config, logger)
        config.each do |attr, value|
          send("#{attr.to_s}=", value) if respond_to?("#{attr.to_s}=")
        end
        
        @active              = nil
        @in_use              = false
        @last_use            = false
        @logger              = logger
        @query_cache         = Hash.new { |h,sql| h[sql] = {} }
        @query_cache_enabled = false
        @schema_cache        = SchemaCache.new self
        @visitor             = nil
        
        @instrumenter = ActiveSupport::Notifications.instrumenter
        
        @pool                = nil
        @open_transactions   = 0
        
        @config = config
        @visitor = BindSubstitution.new self
      end
      
      def lease
        #synchronize do
          unless in_use
            @in_use   = true
            @last_use = Time.now
          end
        #end
      end
      
      def expire
        @in_use = false
      end
      
      # Returns true since this connection adapter supports savepoints
      def supports_savepoints?
        true
      end

      # Returns true.
      def supports_primary_key? #:nodoc:
        true
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        clear_cache!
        @connection = nil
      end

      # Clears the prepared statements cache.
      def clear_cache!
        
      end
      
      def requires_reloading?
        false
      end
      
      
      attr_reader :open_transactions

      def increment_open_transactions
        @open_transactions += 1
      end

      def decrement_open_transactions
        @open_transactions -= 1
      end
      def transaction_joinable=(joinable)
        @transaction_joinable = joinable
      end

      def create_savepoint
      end

      def rollback_to_savepoint
      end

      def release_savepoint
      end

      def case_sensitive_modifier(node)
        node
      end

      def case_insensitive_comparison(table, attribute, column, value)
        table[attribute].lower.eq(table.lower(value))
      end

      def current_savepoint_name
        "active_record_#{open_transactions}"
      end

      # Check the connection back in to the connection pool
      def close
       # pool.checkin self
      end


      def substitute_at(column, index)
        Arel::Nodes::BindParam.new '?'
      end
      
      def active?
        @active != false
      end
      
      def verify!(*ignored)
        reconnect! unless active?
      end
      
      def reconnect!
        @active = true
      end
      
      # Returns true
      def supports_count_distinct? #:nodoc:
        true
      end
      
      # Returns the current database encoding format as a string, eg: 'UTF-8'
      def encoding
        'UTF-8'
      end

      # Returns true.
      def supports_explain?
        false
      end
      
      def explain(arel, binds = [])
        
      end
      # QUOTING ==================================================

      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary && column.class.respond_to?(:string_to_binary)
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        else
          super
        end
      end

      def quote_string(s) #:nodoc:
        s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
      end

      def quote_column_name(name) #:nodoc:
        name
        #%Q("#{name.to_s.gsub('"', '""')}")
      end

      # Quote date/time values for use in SQL input. Includes microseconds
      # if the value is a Time responding to usec.
      def quoted_date(value) #:nodoc:
        if value.respond_to?(:usec)
          "#{super}.#{sprintf("%06d", value.usec)}"
        else
          super
        end
      end

      def type_cast(value, column) # :nodoc:
        return value.to_f if BigDecimal === value
        return super unless String === value
        return super unless column && value

        value = super
        if column.type == :string && value.encoding == Encoding::ASCII_8BIT
          logger.error "Binary data inserted for `string` type on column `#{column.name}`" if logger
          value.encode! 'utf-8'
        end
        value
      end

      # Restfull web service calls ======================================
      def exec_invoke_call(action, id, attributes_with_values = {})
        record.ws_errors = {}
        result = post_ws(resource_uri("#{action}/#{id}"), {}.merge({:attributes => attributes_with_values}))
        
        raise WsRecordInvalid.new(record) if record.ws_errors.present? 
        
        result if result.present?
      end
      
      def exec_select_call(sql, name = nil, binds = [])
        log(sql, name, binds) do
           # Don't cache statements without bind values
          if binds.empty?
            result = post_ws(resource_uri('select'), {:sql => sql})
          else
             #get it from cache
            result = post_ws(resource_uri('select'), {:sql => sql})
          end
          json_parsed_record(result).to_a
        end
      end
      
      def exec_insert_call(id, attributes_with_values = {})
        record.ws_errors = {}
        result = post_ws(resource_uri(), {}.merge({:attributes => attributes_with_values}))
        
        raise WsRecordInvalid.new(record) if record.ws_errors.present? 
        
        obj = json_parsed_record(result) if result.present?
        @last_insert_row_id = obj.to_hash.first['id'] if obj.present?
        #log(sql, name, binds) do
        #end
      end
      
      def exec_delete_call(id)
        record.ws_errors = {}
        delete_ws(resource_uri(id))
        raise WsRecordInvalid.new(record) if record.ws_errors.present? 
        #log(sql, name, binds) do
        #end
      end
      
      def exec_update_call(id, attributes_with_values = {})
        
        record.ws_errors = {}
        result = put_easy_ws(resource_uri(id), {}.merge({:attributes => attributes_with_values}))
        raise WsRecordInvalid.new(record) if record.ws_errors.present? 
        
        rows_affected = 1
        #log(sql, name, binds) do
        #end
      end
      
      def exec_valid_call?(id, attributes_with_values = {})
        record.ws_errors = {}
        result = post_ws(resource_uri('valid'), {}.merge({:id => id, :attributes => attributes_with_values}))
        
        raise WsRecordInvalid.new(record) if record.ws_errors.present? 
        true
      end
      
      def last_inserted_id(result)
        last_insert_row_id
      end
      
      def update_sql(sql, name = nil) #:nodoc:
        puts "update_sql:sql:#{sql}"
        
        #super
        #@connection.changes
      end

      def delete_sql(sql, name = nil) #:nodoc:
        #sql += " WHERE 1=1" unless sql =~ /WHERE/i
        puts "delete_sql:sql:#{sql}"
        #super sql, name
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        puts "insert_sql:sql:#{sql}"
        #super
        #id_value || @connection.last_insert_row_id
      end
      #alias :create :insert_sql

      def select_rows(sql, name = nil)
        exec_select_call(sql, name).rows
      end

      # SCHEMA STATEMENTS ========================================

      def table_exists?(table_name)
        true
      end
      

      # Returns an array of +RestfullJsonColumn+ objects for the table specified by +table_name+.
      def columns(table_name, name = nil) #:nodoc:
        table_fields(table_name).map do |field|
          RestfullJsonColumn.new(field[:name], field[:default], field[:type], field[:null] == true)
        end
      end

      def primary_key(table_name) #:nodoc:
        column = table_fields(table_name).find { |field|
          field[:primary] == true
        }
        column && column[:name]
      end
      
      def table_fields(table_name)
        result = get_ws(resource_uri('fields'))
        
        fields = []
        JSON.parse(result).each do |field|
          fields << ActiveSupport::JSON.decode(field).symbolize_keys
        end
        fields
      end
      
      protected
        def select(sql, name = nil, binds = []) #:nodoc:
          exec_select_call(sql, name, binds)
        end

        def translate_exception(exception, message)
          case exception.message
          when /column(s)? .* (is|are) not unique/
            RecordNotUnique.new(message, exception)
          else
            super
          end
        end
        
        def log(sql, name = "SQL", binds = [])
          @instrumenter.instrument(
            "sql.active_record",
            :sql           => sql,
            :name          => name,
            :connection_id => object_id,
            :binds         => binds) { yield }
        rescue Exception => e
          message = "#{e.class.name}: #{e.message}: #{sql}"
          @logger.debug message if @logger
          exception = translate_exception(e, message)
          exception.set_backtrace e.backtrace
          raise exception
        end

        def translate_exception(e, message)
          # override in derived class
          LogicalRecord::StatementInvalid.new(message)
        end
        
        def logicallogger
          Logger.new(self.log_path || "log/active_record_restfull_json.log")
        end
        
       private
        
        def log_ws_200(res)
          @logger.debug res if @logger
          logicallogger.info("ActiveRecord Log 200: #{res}")
        end
        
        def log_ws_400(res)
          @logger.debug res if @logger
          logicallogger.info("ActiveRecord Log 400: #{res}")
        end
        
        def log_ws_failed(response)
          begin
            if response.body.present?
              error_message = ActiveSupport::JSON.decode(response.body)["message"]
            else
              error_message = ActiveSupport::JSON.decode(response)["message"]
            end
          rescue => e
            error_message = "error"
          end
          message = "ActiveRecord Log Failed: #{response.code} #{response.request.url} in #{response.time}s FAILED: #{error_message}"
            
          logicallogger.warn("ActiveRecord Log: #{message}")
          logicallogger.debug("ActiveRecord Log: #{response.body}") if response.body.present?
          @logger.debug message if @logger
          exception = ActiveRecord::StatementInvalid.new(message)
          exception.set_backtrace e.backtrace if e.present?
          raise exception
        end
          
        def log_easy_ws_failed(easy)
          begin
            if easy.response_body.present?
              error_message = ActiveSupport::JSON.decode(easy.response_body)["message"]
            else
              error_message = easy
            end
          rescue => e
            error_message = "error"
          end
          message = "ActiveRecord Log Failed: #{easy.response_code} #{easy.url} in #{easy.total_time_taken}s FAILED: #{error_message}"
         
          logicallogger.warn("ActiveRecord Log: #{message}")
          logicallogger.debug("ActiveRecord Log: #{message}")
          @logger.debug message if @logger
          exception = ActiveRecord::StatementInvalid.new(message)
          exception.set_backtrace e.backtrace if e.present?
          raise exception
        end
        
        def json_parsed_record(json_string)
          return nil if !json_string.present?
  
          objParsed = JSON.parse(json_string)
          objArray = objParsed.kind_of?(Hash) ?  [objParsed] : objParsed
  
          fields = []
          values = []
          objArray.each do |obj|
            key_values = []
            obj.each do |key, value|
              if !fields.include?(key)
              fields << key
              end
              key_values << value
            end
            values << key_values.flatten
          end
          ActiveRecord::Result.new(fields, values)
        end
        
        def json_parsed_errors(json_string)
          return nil if !json_string.present?
          wsErrors = ActiveSupport::JSON.decode(json_string)
          if wsErrors.present?
            wsErrors.each_key do |k|
              if wsErrors[k].is_a?(Array)
                record.ws_errors[k] = []
                wsErrors[k].map { |msg| record.ws_errors[k] << msg }
              else
                record.ws_errors[k] = []
                record.ws_errors[k] << wsErrors[k]
              end
            end
          end
        end
        
        def post_ws(url, params = {}, body = nil, headers = nil)
          params = params.merge({api_key_name.to_sym => api_key}) if use_api_key
  
          response = nil
          Timeout::timeout(timeout/1000) do
            if body.nil?
              response = Typhoeus::Request.post( url, :params => params, :timeout => timeout )
            else
              response = Typhoeus::Request.post( url, :body => body, :headers => headers, :timeout => timeout )
            end
          end
          if response.code == 200
            if response.body.present?
              log_ws_200(response.body)
              return response.body
            end
          elsif response.code == 400
            if response.body.present?
              log_ws_400(response.body)
              json_parsed_errors(response.body)
            end 
          else
            log_ws_failed(response)
          end
          return nil
        end
        
        def _async_get_ws(url, params = {})
          request = Typhoeus::Request.new( url, :params => params )
      
          request.on_complete do |response|
            if response.code >= 200 && response.code < 400
              if response.body.present?
                log_ws_200(response.body)
                (yield response.body)
              end
            elsif response.code == 400
              if response.body.present?
                log_ws_400(response.body)
                json_parsed_errors(response.body)
              end
            else
              log_ws_failed(response)
            end
          end
          $HYDRA.queue(request)
        end
  
        def get_ws(url, params = {})
          params = params.merge({api_key_name.to_sym => api_key}) if use_api_key 
                  
          result = nil
          _async_get_ws(url, params){|i| result = i}
          Timeout::timeout(timeout/1000) do
            $HYDRA.run
          end
          result
        rescue Timeout::Error
          log_ws_200("timeout")
          return nil
        end
        
        def put_easy_ws(url, params = {})
          params = params.merge({api_key_name.to_sym => api_key}) if use_api_key
          
          # Typhoeus::Easy avoids PUT hang issue: https://github.com/dbalatero/typhoeus/issues/69
          easy = Typhoeus::Easy.new
          easy.url = url
          easy.method = :put
          easy.params = params
          
          Timeout::timeout(timeout/1000) do
            easy.perform
          end
          
          if easy.response_code == 200
            if easy.response_body.present?
              log_ws_200(easy.response_body)
              return easy.response_body
            end
          elsif easy.response_code == 400
            if easy.response_body.present?
              log_ws_400(easy.response_body)
              json_parsed_errors(easy.response_body)
            end
          else
            log_easy_ws_failed(easy)
          end
          return nil
        end
        
        def put_ws(url, params = {})
          params = params.merge({api_key_name.to_sym => api_key}) if use_api_key
          
          response = nil
          Timeout::timeout(timeout/1000) do
            response = Typhoeus::Request.put( url, :params => params, :timeout => timeout )
          end
          if response.code == 200
            if response.body.present?
              log_ws_200(response.body)
              return response.body
            end
          elsif response.code == 400
            if response.body.present?
              log_ws_400(response.body)
              json_parsed_errors(response.body)
            end
          else
            log_ws_failed(response)
          end
          return nil
        end
        
        
        def delete_ws(url, params = {})
          params = params.merge({api_key_name.to_sym => api_key}) if use_api_key
          
          response = nil
          Timeout::timeout(timeout/1000) do
            response = Typhoeus::Request.delete( url, :params => params, :timeout => timeout )
          end
          if response.code == 200
            if response.body.present?
              log_ws_200(response.body)
              return response.body
            end
          elsif response.code == 400
            if response.body.present?
              log_ws_400(response.body)
              json_parsed_errors(response.body)
            end
          else
            log_ws_failed(response)
          end
          return nil
        end 
        
    end
  end
end