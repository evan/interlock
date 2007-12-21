
module Interlock

  class InterlockError < StandardError #:nodoc:
  end  
  class DependencyError < InterlockError #:nodoc:
  end  
  class UsageError < InterlockError #:nodoc:
  end
  class FragmentError < InterlockError #:nodoc:
  end
  
  SCOPE_KEYS = [:controller, :action, :id]
  
  mattr_accessor :local_cache
    
  class << self
    #
    # Extract the dependencies from the rest of the arguments and registers
    # them with the appropriate models.
    # 
    def extract_options_and_dependencies(dependencies, default = nil) 
      options = dependencies.extract_options!
      
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
          raise Interlock::DependencyError, "#{scope.inspect} is not a valid scope" unless [:all, :id].include?(scope)
          dependencies << [klass, scope.to_sym]
        end
      end    

      unless dependencies.any?
        # Use the conventional controller/model association if none are provided
        # Can be skipped by calling caching(nil)
        dependencies = [[default, :all]]
      end
      
      # Remove nils
      dependencies.reject! {|klass, scope| klass.nil? }
      
      [options.indifferentiate, dependencies]
    end 
    
    #
    # Add each key with scope to the appropriate dependencies array.
    #
    def register_dependencies(dependencies, key)
      Array(dependencies).each do |klass, scope|
        dep_key = dependency_key(klass)
        
        # Get the value for this class/key out of the global store.
        this = (CACHE.get(dep_key) || {})[key]

        # Make sure to not overwrite broader scopes.
        unless this == :all or this == scope
          # We need to write, so acquire the lock.            
          CACHE.lock(dep_key) do |hash|
            Interlock.say key, "registered a dependency on #{klass} -> #{scope.inspect}."
            (hash || {}).merge({key => scope})
          end
        end
        
      end
    end

    def say(key, msg) #:nodoc:
      RAILS_DEFAULT_LOGGER.warn "** fragment #{key.inspect[1..-2]} #{msg}"
    end
     
    #   
    # Get the Memcached key for a class's dependency list. We store per-class 
    # to reduce lock contention.
    #
    def dependency_key(klass) 
      "interlock:#{ENV['RAILS_ASSET_ID']}:dependency:#{klass.name}"
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
