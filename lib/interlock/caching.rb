
ActionController::Base
ActionView::Helpers::CacheHelper
ActiveRecord::Base

class ActionController::Base

  self.fragment_cache_store = CACHE   

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
  def caching_key(tag = nil)
    if tag.is_a? Array and tag.all? {|x| x.is_a? Symbol}
      # XXX Should probably sort by key-order, not value-order
      tag = tag.map { |key| params[key].to_interlock_tag }.sort.join(";")
    end
    Interlock.caching_key(controller_name, action_name, params[:id], tag)
  end
  
  # Mark a controller block for caching. Accepts a list of class dependencies for
  # invalidation, as well as a :tag key for explicit fragment scoping.
  def behavior_cache(*args)  
    options, dependencies = Interlock.extract_options_and_dependencies(args)
    key = caching_key(options.value_for_indifferent_key(:tag))      
    Interlock.register_dependencies(dependencies, key)
        
    # See if the fragment exists, and run the block if it doesn't.
    unless ActionController::Base.fragment_cache_store.get(key)    
      Interlock.say key, "is running the controller block"
      yield
    end
  end
  
  alias :caching :behavior_cache # XXX Legacy

end

module ActionView::Helpers::CacheHelper
  
  # Mark a corresponding view block for caching. Accepts a :tag key for 
  # explicit scoping. You can specify dependencies here if you really want to.
  def view_cache(*args, &block)
    options, dependencies = Interlock.extract_options_and_dependencies(args)  
    key = controller.caching_key(options.value_for_indifferent_key(:tag))      
    Interlock.register_dependencies(dependencies, key)

    Interlock.say key, "is rendering"
    @controller.cache_erb_fragment(
      block, 
      key, 
      :ttl => (options.value_for_indifferent_key(:ttl) or Interlock.config[:ttl])
    )
  end
  
  alias :caching :view_cache # XXX Legacy
  
end

class ActiveRecord::Base

  def self.caching_dependencies #:nodoc:
    @caching_dependencies ||= []
  end
  
  # Add a key/scope dependency pair to this class.
  def self.add_caching_dependency(key, scope)
    if !caching_dependencies.include?([key, scope])
      Interlock.say key, "registered a dependency on #{self} -> #{scope.inspect}."
      caching_dependencies << [key, scope]
    end
  end   
  
  # The expiry callback.
  def expire_interlock_keys
    self.class.caching_dependencies.each do |key, scope|
      if scope == :all or (scope == :id and key.field(4) == self.to_param.to_s)
        Interlock.say key, "invalidated by rule #{self.class} -> #{scope.inspect}."
        Interlock.invalidate key
      end
    end
  end
  
  before_save :expire_interlock_keys
  after_destroy :expire_interlock_keys
  
end
