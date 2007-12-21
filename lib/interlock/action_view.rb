
module ActionView #:nodoc:
  class Base #:nodoc:
    attr_accessor :cached_content_for
  end

  module Helpers #:nodoc:
    module CacheHelper 
     
=begin rdoc     

<tt>view_cache</tt> marks a corresponding view block for caching. It accepts <tt>:tag</tt> and <tt>:ignore</tt> keys for explicit scoping, as well as a <tt>:ttl</tt> key and a <tt>:perform</tt> key. 

You can specify dependencies in <tt>view_cache</tt> if you really want to. 

== TTL

Use the <tt>:ttl</tt> key to specify a maximum time-to-live, in seconds:

  <% view_cache :ttl => 5.minutes do %>
  <% end %>

Note that the cache is not guaranteed to persist this long. An invalidation rule could trigger first, or memcached could eject the item early due to the LRU.

== View caching without action caching

It's fine to use a <tt>view_cache</tt> block without a <tt>behavior_cache</tt> block. For example, to mimic regular fragment cache behavior, but take advantage of memcached's <tt>:ttl</tt> support, call:

  <% view_cache nil, :ignore => :all, :tag => 'sidebar', :ttl => 5.minutes %>
  <% end %> 
  
Remember that <tt>nil</tt> disables invalidation rules. This is a nice trick for keeping your caching strategy unified.

== Dependencies, scoping, and other options

See ActionController::Base for explanations of the rest of the options. The <tt>view_cache</tt> and <tt>behavior_cache</tt> APIs are identical except for setting the <tt>:ttl</tt>, which can only be done in the view.

=end     
     def view_cache(*args, &block)       
       conventional_class = begin; controller.controller_name.classify.constantize; rescue NameError; end
       options, dependencies = Interlock.extract_options_and_dependencies(args, conventional_class)  

       key = controller.caching_key(options.value_for_indifferent_key(:ignore), options.value_for_indifferent_key(:tag))      
       
       if options[:perform] == false
         # Interlock.say key, "is not cached"
         block.call
       else       
         Interlock.register_dependencies(dependencies, key)

         # Interlock.say key, "is rendering"

         @cached_content_for = {}
         @controller.cache_erb_fragment(
           block, 
           key, 
           :ttl => (options.value_for_indifferent_key(:ttl) or Interlock.config[:ttl])
         )
         @cached_content_for = nil
       end
     end
     
    #:stopdoc:
    alias :caching :view_cache # Deprecated
    #:startdoc:
     
    end

  
    module CaptureHelper
      #
      # Override content_for so we can cache the instance variables it sets along with the fragment.
      #
      def content_for(name, content = nil, &block)
        name = "@content_for_#{name}"
        existing_content = instance_variable_get(name).to_s
        this_content = (block_given? ? capture(&block) : content)
        
        # If we are in a view_cache block, cache what we added to this instance variable
        if @cached_content_for
          @cached_content_for[name] = "#{@cached_content_for[name]}#{this_content}"
        end
        
        instance_variable_set(name, existing_content + this_content)
      end    
    end

  end
end
