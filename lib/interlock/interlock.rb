
module Interlock

  class DependencyError < StandardError
  end  
  
  mattr_accessor :config  
  @@config = {:ttl => 1.day}

  class << self

    #
    # Extract the dependencies from the rest of the arguments and registers
    # them with the appropriate models.
    # 
    def extract_options_and_register_dependencies(dependencies)
      options = ActiveRecord::Base.send(:extract_options_from_args!, dependencies)
      
      # Hook up the dependencies nested array.
      dependencies.map! { |klass| [klass, :all] }
      options.each do |klass, scope| 
        if klass.is_a? Class 
          #
          # Beware! Scoping to :id means that a request's params[:id] must equal 
          # klass#id or the rule will not trigger. This is because params[:id] is the
          # only record-specific scope include in the key. 
          #
          # If you want fancier invalidation, think hard about whether it really 
          # matters. Over-invalidation is rarely a problem, but under-invalidation
          # frequently is. 
          #
          # "But I need it!" you say. All right, then start using key tags.
          #
          raise Interlock::DependencyError, "#{scope} is not a valid scope" unless [:all, :id].include?(scope)
          dependencies << [klass, scope.to_sym]
        end
      end    

      unless dependencies.any?
        # Use the conventional controller/model association if none are provided
        # Can be skipped by calling caching(nil)
        dependencies = [[controller_name.classify.constantize, :all]] rescue []
      end
      
      # Add each key with scope to the appropriate dependencies array.
      dependencies.compact.each do |klass, scope|
        klass.add_caching_dependency key, scope
      end
      
      options.indifferentiate
    end 

    def say(key, msg) #:nodoc:
      RAILS_DEFAULT_LOGGER.warn "** fragment #{key.inspect} #{msg}"
    end
    
    # 
    # Build a fragment key for an explicitly passed context. Shouldn't be called
    # unless you need to write your own fine-grained invalidation rules. Make sure
    # the default ones are really unacceptable before you go to the trouble of
    # rolling your own.
    #
    def caching_key(controller, action, id, tag)
      raise ArgumentError, "Both controller and action must be specified" unless controller and action
      
      id = (id or 'all').to_interlock_tag
      tag = tag.to_interlock_tag

      "interlock:#{ENV['RAILS_ASSET_ID']}:#{controller}:#{action}:#{id}:#{tag}"
    end
    
    #
    # Invalidate a particular key.
    #
    def invalidate(key)
      ActionController::Base.fragment_cache_store.delete key
    end    
    
  end    
end
