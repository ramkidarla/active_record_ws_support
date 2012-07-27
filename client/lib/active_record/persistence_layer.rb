require 'active_support/concern'


module ActiveRecord
  # = Active Record Persistence
  module PersistenceLayer
    extend ActiveSupport::Concern
    
    def invoke(action, attributes_with_values = {})
      begin
        self.class.connection.record = self
        result = self.class.connection.exec_invoke_call(action, id, attributes_with_values)
        clear_ws_errors
        result
      rescue ActiveRecord::WsRecordInvalid
        add_ws_errors
        self
      end
    end
    
    def save(*)
      if self.class.connection.adapter_name == 'RestfullJson'
        begin
          create_or_update_layer
          clear_ws_errors
          true
        rescue ActiveRecord::RecordInvalid
          false
        rescue ActiveRecord::WsRecordInvalid
          add_ws_errors
          false
        end
      else
        super
      end
    end

    def save!(*)
     if self.class.connection.adapter_name == 'RestfullJson'
      begin
        create_or_update_layer || raise(RecordNotSaved)
        clear_ws_errors
        true
      rescue ActiveRecord::WsRecordInvalid
        add_ws_errors
        raise(RecordNotSaved)
      end
     else
       super
     end
    end

    def delete
     if self.class.connection.adapter_name == 'RestfullJson'
      if persisted?
        begin
          self.class.delete(id)
          IdentityMap.remove(self) if IdentityMap.enabled?
          clear_ws_errors 
        rescue ActiveRecord::WsRecordInvalid => exception
          self.ws_errors = exception.record.ws_errors
        end
      end
      add_ws_errors
      return self if ws_errors.present?
      
      @destroyed = true
      freeze
     else
       super
     end
    end

    def destroy
     if self.class.connection.adapter_name == 'RestfullJson'
      destroy_associations

      if persisted?
        IdentityMap.remove(self) if IdentityMap.enabled?
        pk         = self.class.primary_key
        column     = self.class.columns_hash[pk]
        substitute = connection.substitute_at(column, 0)

        relation = self.class.unscoped.where(
          self.class.arel_table[pk].eq(substitute))
        
        begin
          relation.bind_values = [[column, id]]
          relation.delete_all
          clear_ws_errors 
        rescue ActiveRecord::WsRecordInvalid => exception
          self.ws_errors = exception.record.ws_errors
        end
      end
      add_ws_errors
      return self if ws_errors.present?
      
      @destroyed = true
      freeze
     else
       super
     end
    end

    def update_column(name, value)
     if self.class.connection.adapter_name == 'RestfullJson'
      begin
        name = name.to_s
        raise ActiveRecordError, "#{name} is marked as readonly" if self.class.readonly_attributes.include?(name)
        raise ActiveRecordError, "can not update on a new record object" unless persisted?
        raw_write_attribute(name, value)
        result = self.class.update_all({ name => value }, self.class.primary_key => id) == 1
        clear_ws_errors
        result
      rescue ActiveRecord::WsRecordInvalid => exception
        self.ws_errors = exception.record.ws_errors
        add_ws_errors
        false
      end
     else
       super
     end
    end
    
    def update_attributes(attributes, options = {})
      if self.class.connection.adapter_name == 'RestfullJson'
        with_transaction_returning_status do
          self.assign_attributes(attributes, options)
          save
        end
      else
        super
      end
    end

    def update_attributes!(attributes, options = {})
      if self.class.connection.adapter_name == 'RestfullJson'
        with_transaction_returning_status do
          self.assign_attributes(attributes, options)
          save!
        end
      else
        super
      end
    end
    
    
    def touch(name = nil)
      if self.class.connection.adapter_name == 'RestfullJson'
        begin
          attributes = timestamp_attributes_for_update_in_model
          attributes << name if name
          
          
          unless attributes.empty?
            current_time = current_time_from_proper_timezone
            changes = {}
    
            attributes.each do |column|
              changes[column.to_s] = write_attribute(column.to_s, current_time)
            end
    
            changes[self.class.locking_column] = increment_lock if locking_enabled?
    
            @changed_attributes.except!(*changes.keys)
            primary_key = self.class.primary_key
            
            self.class.connection.record = self
            result = self.class.connection.exec_update_call(id, changes) == 1
            clear_ws_errors
            result
          end
        rescue ActiveRecord::WsRecordInvalid
          add_ws_errors
          false
        end
      else
        super
      end
      
    end
    
    def ws_valid?
      attributes_with_values = attributes_with_values(false, false, attribute_names)
      self.class.connection.record = self
      result = self.class.connection.valid_call?(id, attributes_with_values)
      clear_ws_errors
      result
    rescue ActiveRecord::WsRecordInvalid
      add_ws_errors
      false
    end
    
    def add_ws_errors
      errors.clear if errors.present?
      ws_errors.each do |key, value|  
        if value.is_a?(Array)
          value.map { |msg| errors.add key, msg }
        else
          errors.add key, value
        end
      end if ws_errors.present?
    end
    
    def clear_ws_errors
      ws_errors.clear if ws_errors.present?
      errors.clear if errors.present? 
    end
  private

    def destroy_associations
      if self.class.connection.adapter_name == 'RestfullJson'
         return
      else
        super
      end
    end

    def create_or_update_layer
      raise ReadOnlyRecord if readonly?
      result = new_record? ? create_layer : update_layer
      result != false
    end

    def update_layer(attribute_names = @attributes.keys)
      attributes_with_values = attributes_with_values(false, false, attribute_names)
      return 0 if attributes_with_values.empty?
      klass = self.class
      
      begin
        klass.connection.record = self
        klass.connection.exec_update_call(id, attributes_with_values)
      rescue ActiveRecord::WsRecordInvalid => exception
        raise exception
      end
    end

    def create_layer
      attributes_values = attributes_with_values(!id.nil?)

      new_id = self.class.unscoped.insert attributes_values, self

      self.id ||= new_id if self.class.primary_key

      IdentityMap.add(self) if IdentityMap.enabled?
      @new_record = false
      id
    end
  end
end
