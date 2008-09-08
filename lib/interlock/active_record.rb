
module ActiveRecord #:nodoc:
  class Base

    class << self # Class methods
    
      def update_counters_with_expiring_keys(id, counters)
        update_counters_without_expiring_keys(id, counters)
        find(id).expire_interlock_keys
      end
      alias :update_counters_without_expiring_keys :update_counters
      alias :update_counters :update_counters_with_expiring_keys
      
    end
    
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
      (CACHE.get(Interlock.dependency_key(self.class.base_class)) || {}).each do |key, scope|
        if scope == :all or (scope == :id and key.field(4) == self.to_param.to_s)
          Interlock.say key, "invalidated by rule #{self.class} -> #{scope.inspect}."
          Interlock.invalidate key
        end
      end
      
      # Models
      if Interlock.config[:with_finders]
        key = self.class.base_class.caching_key(self.id)
        Interlock.say key, 'invalidated with finders', 'model'
        Interlock.invalidate(key)
      end
    end
    

    before_save :expire_interlock_keys
    after_destroy :expire_interlock_keys

    #
    # Reload. Expires the cache and force reload from db.
    #
    def reload_with_expiring_keys
      self.expire_interlock_keys
      reload_without_expiring_keys
    end
    alias :reload_without_expiring_keys :reload
    alias :reload :reload_with_expiring_keys
    
  end
end
