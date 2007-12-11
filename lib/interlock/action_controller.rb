
module ActionController
  class Base
  
    #
    # Build the fragment key from a particular context. This must be deterministic 
    # and stateful except for the tag. We can't scope the key to arbitrary params 
    # because the view doesn't have access to which are relevant and which are 
    # not.
    #
    # Note that the tag can be pretty much any object. Define #to_interlock_tag
    # if you need custom tagging for some class. ActiveRecord::Base already
    # has it defined appropriately.
    #
    # If you pass an Array of symbols as the tag, it will get value-mapped onto
    # params and sorted. This makes granular scoping easier, although it doesn't
    # sidestep the normal blanket invalidations.
    #
    def caching_key(ignore = nil, tag = nil)
      ignore = Array(ignore)
      ignore = Interlock::SCOPE_KEYS if ignore.include? :all    
      
      if (Interlock::SCOPE_KEYS - ignore).empty? and !tag
        raise UsageError, "You must specify a :tag if you are ignoring the entire default scope."
      end
        
      if tag.is_a? Array and tag.all? {|x| x.is_a? Symbol}
        tag = tag.sort_by do |key|
          key.to_s
        end.map do |key| 
          params[key].to_interlock_tag
        end.join(";")
      end
      
      Interlock.caching_key(      
        ignore.include?(:controller) ? 'any' : controller_name,
        ignore.include?(:action) ? 'any' : action_name,
        ignore.include?(:id) ? 'all' : params[:id],
        tag
      )
    end
    
    # Mark a controller block for caching. Accepts a list of class dependencies for
    # invalidation, as well as a :tag key for explicit fragment scoping.
    def behavior_cache(*args)  
      conventional_class = begin; controller_name.classify.constantize; rescue NameError; end
      options, dependencies = Interlock.extract_options_and_dependencies(args, conventional_class)
      
      raise UsageError, ":ttl has no effect in a behavior_cache block" if options[:ttl]
      
      key = caching_key(options.value_for_indifferent_key(:ignore), options.value_for_indifferent_key(:tag))      
      Interlock.register_dependencies(dependencies, key)
          
      # See if the fragment exists, and run the block if it doesn't.
      unless read_fragment(key)    
        Interlock.say key, "is running the controller block"
        yield
      end
    end
    
    alias :caching :behavior_cache # XXX Deprecated

    private

    # 
    # Callback to reset the local cache.
    #
    def clear_interlock_local_cache
      Interlock.local_cache = ActionController::Base::MemoryStore.new
      RAILS_DEFAULT_LOGGER.warn "** cleared interlock local cache"
    end    
    before_filter :clear_interlock_local_cache
  
  end
  
  module Caching
    module Fragments
       
      #
      # Replaces Rail's write_fragment method. Avoids extra checks for regex keys, 
      # which are unsupported; adds more detailed logging information, and stores 
      # writes in the local process cache too to avoid duplicate memcached requests.
      #
      def write_fragment(key, content, options = nil)
        return unless perform_caching

        fragment_cache_store.write(key, content, options)
        Interlock.local_cache.write(key, content, options)

        Interlock.say key, "wrote"

        content
      end

      #
      # Replaces Rail's read_fragment method. Avoids checks for regex keys, 
      # which are unsupported; adds more detailed logging information; and
      # checks the local process cache before hitting memcached. Hits on 
      # memcached are then stored back locally to avoid duplicate requests.
      #
      def read_fragment(key, options = nil)
        return unless perform_caching

        if content = Interlock.local_cache.read(key, options)
          # Interlock.say key, "read from local cache"
        elsif content = fragment_cache_store.read(key, options)            
          Interlock.say key, "read from memcached"
          Interlock.local_cache.write(key, content, options)
        else
          Interlock.say key, "not found"
        end
        content
      end      
      
    end
  end    
end
