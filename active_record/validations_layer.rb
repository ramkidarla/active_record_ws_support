module ActiveRecord
  module ValidationsLayer
    extend ActiveSupport::Concern
   
    # The validation process on save can be skipped by passing <tt>:validate => false</tt>. The regular Base#save method is
    # replaced with this when the validations module is mixed in, which it is by default.
    def save(options={})
      if self.class.connection.adapter_name == 'RestfullJson'
        __perform_validations(options) ? super : false
      else
        super
      end
    end

    # Attempts to save the record just like Base#save but will raise a +RecordInvalid+ exception instead of returning false
    # if the record is not valid.
    def save!(options={})
      if self.class.connection.adapter_name == 'RestfullJson'
        __perform_validations(options) ? super : raise(RecordInvalid.new(self))
      else
        super
      end
    end

    # Runs all the validations within the specified context. Returns true if no errors are found,
    # false otherwise.
    #
    # If the argument is false (default is +nil+), the context is set to <tt>:create</tt> if
    # <tt>new_record?</tt> is true, and to <tt>:update</tt> if it is not.
    #
    # Validations with no <tt>:on</tt> option will run no matter the context. Validations with
    # some <tt>:on</tt> option will only run in the specified context.
    def valid?(context = nil)
      if self.class.connection.adapter_name == 'RestfullJson'
        return super(context) if context.present?
        valid_local? && ws_valid?
      else
        super
      end
    end
    
    def valid_local?(context = nil)
      context ||= (new_record? ? :create : :update)
      output = valid?(context)
      errors.empty? && output
    end   
     
  protected

    def __perform_validations(options={})
      perform_validation = options[:validate] != false
      perform_validation ? valid_local?(options[:context]) : true
    end
  end
end
