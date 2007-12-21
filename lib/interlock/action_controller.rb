
module ActionController #:nodoc:
  class Base
  

=begin rdoc
Build the fragment key from a particular context. This must be deterministic and stateful except for the tag. We can't scope the key to arbitrary params because the view doesn't have access to which are relevant and which are not.

Note that the tag can be pretty much any object. Define <tt>to_interlock_tag</tt> if you need custom tagging for some class. ActiveRecord::Base already has it defined appropriately.

If you pass an Array of symbols as the tag, it will get value-mapped onto params and sorted. This makes granular scoping easier, although it doesn't sidestep the normal blanket invalidations.
=end

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
    

=begin rdoc    
    
<tt>behavior_cache</tt> marks a controller block for caching. It accepts a list of class dependencies for invalidation, as well as as <tt>:tag</tt> and <tt>:ignore</tt> keys for explicit fragment scoping. It does not accept a <tt>:ttl</tt> key.

== Declaring dependencies

You can declare non-default invalidation dependencies by passing models to <tt>behavior_cache</tt> (you can also pass them to <tt>view_cache</tt>, but you should only do that if you are caching a fragment without an associated behavior block in the controller).

<b>No dependencies (cache never invalidates):</b>
  behavior_cache nil do
  end
  
<b>Invalidate on any Media change:</b>
  behavior_cache Media do
  end
  
<b>Invalidate on any Media or Item change:</b>
  behavior_cache Media, Item do
  end
  
<b>Invalidate on Item changes if the Item <tt>id</tt> matches the current <tt>params[:id]</tt> value:</b>
  behavior_cache Item => :id do
  end

You do not have to pass the same dependencies to <tt>behavior_cache</tt> and <tt>view_cache</tt> even for the same action. The set union of both dependency lists will be used.

== Narrowing scope and caching multiple blocks

Sometimes you need to cache multiple blocks in a controller, or otherwise get a more fine-grained scope. Interlock provides the <tt>:tag</tt> key for this purpose. <tt>:tag</tt> accepts either an array of symbols, which are mapped to <tt>params</tt> values, or an arbitrary object, which is converted to a string identifier. <b>Your corresponding behavior caches and view caches must have identical <tt>:tag</tt> values for the interlocking to take effect.</b>

Note that <tt>:tag</tt> can be used to scope caches. You can simultaneously cache different versions of the same block, differentiating based on params or other logic. This is great for caching per-user, for example:

  def profile
    @user = current_user
    behavior_cache :tag => @user do
      @items = @user.items
    end
  end

In the view, use the same <tt>:tag</tt> value (<tt>@user</tt>). Note that <tt>@user</tt> must be set outside of the behavior block in the controller, because its contents are used to decide whether to run the block in the first place.

This way each user will see only their own cache. Pretty neat.

== Broadening scope

Sometimes the default scope (<tt>controller</tt>, <tt>action</tt>, <tt>params[:id]</tt>) is too narrow. For example, you might share a partial across actions, and set up its data via a filter. By default, Interlock will cache a separate version of it for each action. To avoid this, you can use the <tt>:ignore</tt> key, which lets you list parts of the default scope to ignore:

  before_filter :recent
  
  private
  
  def recent
    behavior_cache :ignore => :action do
      @recent = Item.find(:all, :limit => 5, :order => 'updated_at DESC')
    end
  end

Valid values for <tt>:ignore</tt> are <tt>:controller</tt>, <tt>:action</tt>, <tt>:id</tt>, and <tt>:all</tt>. You can pass an array of multiple values. <b>Just like with <tt>:tag</tt>, your corresponding behavior caches and view caches must have identical <tt>:ignore</tt> values.</b> Note that cache blocks with <tt>:ignore</tt> values still obey the regular invalidation rules.

A good way to get started is to just use the default scope. Then <tt>grep</tt> in the production log for <tt>interlock</tt> and see what keys are being set and read. If you see lots of different keys go by for data that you know is the same, then set some <tt>:ignore</tt> values. 

== Skipping caching

You can pass <tt>:perform => false</tt> to disable caching, for example, in a preview action. Note that <tt>:perform</tt> only responds to <tt>false</tt>, not <tt>nil</tt>. This allows for handier view reuse because you can set <tt>:perform</tt> to an instance variable and it will still cache if the instance variable is not set:

  def preview
    @perform = false
    behavior_cache :perform => @perform do
    end
    render :action => 'show'
  end
  
And in the <tt>show.html.erb</tt> view:

  <% view_cache :perform => @perform do %>
  <% end %>

=end    
    
    def behavior_cache(*args)  
      conventional_class = begin; controller_name.classify.constantize; rescue NameError; end
      options, dependencies = Interlock.extract_options_and_dependencies(args, conventional_class)
      
      raise UsageError, ":ttl has no effect in a behavior_cache block" if options[:ttl]

      key = caching_key(options.value_for_indifferent_key(:ignore), options.value_for_indifferent_key(:tag))      

      if options[:perform] == false
        Interlock.say key, "is not cached"
        yield
      else
        Interlock.register_dependencies(dependencies, key)
            
        # See if the fragment exists, and run the block if it doesn't.
        unless read_fragment(key, :assign_content_for => false)
          Interlock.say key, "is running the controller block"
          yield
        end
      end
    end
    
    #:stopdoc:
    alias :caching :behavior_cache # Deprecated
    #:startdoc:

    private

    # 
    # Callback to reset the local cache.
    #
    def clear_interlock_local_cache
      Interlock.local_cache = ActionController::Base::MemoryStore.new
      RAILS_DEFAULT_LOGGER.warn "** cleared interlock local cache"
    end    
    
    # Should be registered first in the chain
    prepend_before_filter :clear_interlock_local_cache 
  
  end
  
  module Caching #:nodoc:
    module Fragments
       
      #
      # Replaces Rail's write_fragment method. Avoids extra checks for regex keys, 
      # which are unsupported, adds more detailed logging information, and stores 
      # writes in the local process cache too to avoid duplicate memcached requests.
      #
      def write_fragment(key, block_content, options = nil)
        return unless perform_caching
        
        content = [block_content, @template.cached_content_for]

        fragment_cache_store.write(key, content, options)
        Interlock.local_cache.write(key, content, options)

        Interlock.say key, "wrote"

        block_content
      end

      #
      # Replaces Rail's read_fragment method. Avoids checks for regex keys, 
      # which are unsupported, adds more detailed logging information, and
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
          # Interlock.say key, "not found"
          return nil
        end
        
        raise Interlock::FragmentError "Fragment #{key} was not set by Interlock" unless content.is_a? Array

        options ||= {}
        unless options[:assign_content_for] == false
          # Extract content_for variables
          content.last.each do |name, value| 
            # Make sure to append, not overwrite
            existing_content = @template.instance_variable_get(name)
            @template.instance_variable_set(name, "#{existing_content}#{value}")
            Interlock.say key, "set #{name} as #{value.inspect}"
          end
        end

        content.first        
      end      
      
    end
  end    
end
