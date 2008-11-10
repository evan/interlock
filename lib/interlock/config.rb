#require 'ehcache'
module Interlock

  DEFAULTS = {
    :ttl => 1.day,
    :namespace => 'app',
    :servers => ['127.0.0.1:11211'],
    :client => 'memcache-client',
    :with_finders => false
  }    
  
  CLIENT_KEYS = [ 
    :hash,
    :no_block,
    :buffer_requests,
    :support_cas,
    :tcp_nodelay,
    :distribution,
    :namespace
  ] 

  mattr_accessor :config 
  @@config = DEFAULTS
  
  module Config
    
    CONFIG_FILE = "#{RAILS_ROOT}/config/memcached.yml"
  
    class << self
  
      #
      # Load the configuration file, if available, and then set up the Memcached instance,
      # Rails settings, and CACHE constants. Should be more or less compatible with
      # Cache_fu.
      #
      def run!
        if File.exist?(CONFIG_FILE)
          template = ERB.new(File.open(CONFIG_FILE) {|f| f.read})       
          config = YAML.load(template.result(binding))
          config.deep_symbolize_keys!

          Interlock.config.merge!(config[:defaults] || {})
          Interlock.config.merge!(config[RAILS_ENV.to_sym] || {})
        end

        install_memcached
        install_fragments        

        # Always install the finders.
        install_finders if Interlock.config[:with_finders]
      end
  
      # 
      # Configure memcached for this app.
      #
      def install_memcached
        Interlock.config[:namespace] << (RAILS_ENV == 'production' ? ':pro:' : ':dev:')
  
        unless defined? Object::CACHE

          # Give people a choice of client, even though I don't like conditional dependencies.
          klass = case Interlock.config[:client]
            when 'memcached'
              begin
                Memcached::Rails
              rescue ArgumentError
                raise ConfigurationError, "'memcached' client requested but not installed. Try 'sudo gem install memcached'."
              end
              
            when 'memcache-client'              
              begin
                if MemCache.constants.include?('SVNURL')
                  raise ConfigurationError, "You have the Ruby-MemCache gem installed. Please uninstall Ruby-MemCache, or otherwise guarantee that memcache-client will load instead." 
                end
                MemCache              
              rescue ArgumentError
                raise ConfigurationError, "'memcache-client' client requested but not installed. Try 'sudo gem install memcache-client'."
              end
              
            when 'ehcache' 
              Ehcache::CacheManager.new.cache
            else
              raise ConfigurationError, "Invalid client name '#{Interlock.config[:client]}'"
          end
          
          unless Interlock.config[:client] == 'ehcache'
            Object.const_set('CACHE', 
              klass.new(
                Interlock.config[:servers], 
                Interlock.config.slice(*CLIENT_KEYS)
              )
            )
          else
            Object.const_set('CACHE', klass)
          end

          # Mark that we're the ones who did it.
          class << CACHE
            def installed_by_interlock; true; end
          end
          
        else
          begin
            CACHE.installed_by_interlock
          rescue NoMethodError
            RAILS_DEFAULT_LOGGER.warn "** interlock: Object::CACHE already defined; will not install a new one"
            # Mark that somebody else installed this CACHE.
            class << CACHE
              def installed_by_interlock; false; end
            end
          end
        end
        
        # Add the fragment cache and lock APIs to the cache singleton. This happens no matter
        # who installed the singleton.
        class << CACHE
          include Interlock::Lock
          
          # def read(*args)
          #   get args.first.to_s
          # end
          # 
          # def write(name, content, options = {})             
          #   set(name.to_s, 
          #     content, 
          #     options.is_a?(Hash) ? options[:ttl] : Interlock.config[:ttl] )
          # end
          def read(*args) 
            key = Interlock.convert_key(args.first.to_s) 
            return nil if update_required?(key) 
            get key 
          end
          
          def write(name, content, options = {}) 
            name = Interlock.convert_key(name) 
            if options.is_a?(Hash) && options.key?(:expire) 
              set("#{name}_expiry",  Time.now + options[:expire].seconds) 
              update_and_unlock(name) { content } 
            else 
              set(name,  
                content,  
                options.is_a?(Hash) ? options[:ttl] : Interlock.config[:ttl] ) 
            end
          end
          
          private 
         	 
         	def update_required?(key) 
         	  expiry_time = get("#{key}_expiry") 
         	  expiry_time && expiry_time < Time.now && lock_for_update(key) 
         	end
        end    
      end
      
      #
      # Configure Rails to use the memcached store for fragments, and optionally, sessions.
      #    
      def install_fragments
        # Memcached fragment caching is mandatory        
        ActionView::Helpers::CacheHelper.class_eval do
          def cache(name = {}, options = nil, &block)
            # Things explode if options does not default to nil
            RAILS_DEFAULT_LOGGER.debug "** fragment #{name} stored via obsolete cache() call"
            @controller.fragment_for(output_buffer, name, options, &block)
          end
        end                
        ActionController::Base.cache_store = CACHE
  
        # Sessions are optional
        if Interlock.config[:sessions]
          # XXX Right now this requires memcache-client to be installed, due to a Rails problem.
          # http://dev.rubyonrails.org/ticket/11290
          ActionController::Base.session_store = :mem_cache_store
          ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.update 'cache' => CACHE      
        end      
      end    
      
      #
      # Configure ActiveRecord#find caching.
      #
      def install_finders
        # RAILS_DEFAULT_LOGGER.warn "** using interlock finder caches"
        ActiveRecord::Base.send(:include, Interlock::Finders)
      end

    end
  end
end
