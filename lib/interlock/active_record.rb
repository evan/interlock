
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
      (CACHE.get(Interlock.dependency_key(self.class.base_class)) || {}).each do |key, scope|
        if scope == :all or (scope == :id and key.field(4) == self.to_param.to_s)
          Interlock.say key, "invalidated by rule #{self.class} -> #{scope.inspect}."
          Interlock.invalidate key
        end
      end
    end
    
    before_save :expire_interlock_keys
    after_destroy :expire_interlock_keys

  end
end