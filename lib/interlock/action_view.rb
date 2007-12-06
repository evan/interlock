
module ActionView::Helpers::CacheHelper
  
  # Mark a corresponding view block for caching. Accepts a :tag key for 
  # explicit scoping. You can specify dependencies here if you really want to.
  def view_cache(*args, &block)
    conventional_class = begin; controller.controller_name.classify.constantize; rescue NameError; end
    options, dependencies = Interlock.extract_options_and_dependencies(args, conventional_class)  
    
    key = controller.caching_key(options.value_for_indifferent_key(:ignore), options.value_for_indifferent_key(:tag))      
    Interlock.register_dependencies(dependencies, key)

    Interlock.say key, "is rendering"
    @controller.cache_erb_fragment(
      block, 
      key, 
      :ttl => (options.value_for_indifferent_key(:ttl) or Interlock.config[:ttl])
    )
  end
  
  alias :caching :view_cache # XXX Deprecated
  
end
