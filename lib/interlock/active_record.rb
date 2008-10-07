
module ActiveRecord #:nodoc:
  class Base

    @@nil_sentinel = :_nil

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
        Interlock.invalidate(self.class.base_class.caching_key(self.id))
      end
    end
    

    before_save :expire_interlock_keys
    after_destroy :expire_interlock_keys

    #
    # Reload. Expires the cache and force reload from db.
    #
    # def reload
    #   self.expire_interlock_keys
    #   super
    # end

    def self.get_cache(key) 
      return yield if Interlock.config[:disabled] 
      data = CACHE.get(self.formalize(key)) 
      return (data == @@nil_sentinel ? nil : data) unless data.nil? 

      data = yield  

      CACHE.set(self.formalize(key), data || @@nil_sentinel) 
      return data 
    end 

    def self.expire_cache(key) 
      CACHE.delete(self.formalize(key)) 
    end 

  protected 

    def self.formalize(key) 
      return [self.class_name, ':', Digest::MD5.hexdigest(key.to_s)].join 
    end
     
  end
end
