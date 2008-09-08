
module ActiveRecord #:nodoc:
  class Base


    #
    # Convert this record to a tag string.
    #
    def to_interlock_tag
      "#{self.class.name}-#{self.id}".escape_tag_fragment
    end        

    #
    # The expiry callback.
    #
    def expire_interlock_keys
      return if Interlock.config[:disabled] or (defined? CGI::Session::ActiveRecordStore and is_a? CGI::Session::ActiveRecordStore::Session)
      
      # Fragments
      self.expire_keys_for_dependency(Interlock.dependency_key(self.class.base_class.name, :all, nil))
      self.expire_keys_for_dependency(Interlock.dependency_key(self.class.base_class.name, :id, "::::#{self.to_param.to_s}:"))
      
      # Models
      if Interlock.config[:with_finders]
        Interlock.invalidate(self.class.base_class.caching_key(self.id))
      end
    end
    
    after_save :expire_interlock_keys
    after_destroy :expire_interlock_keys

    #
    # Reload. Expires the cache and force reload from db.
    #
    def reload
      self.expire_interlock_keys
      super
    end

    private
    
      def expire_keys_for_dependency(dependency_key)

        (CACHE.get(dependency_key) || {}).each do |key, scope|
          Interlock.say key, "invalidated by rule #{self.class} -> #{scope.inspect}."
          Interlock.invalidate key
        end      

      end
            
  end
end
