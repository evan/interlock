
module Interlock

  DEFAULTS = {
    :ttl => 1.day,
    :namespace => 'app',
    :servers => ['127.0.0.1:11211'],
    :client => 'memcache-client',
    :with_finders => false
  }    
  
  CLIENT_KEYS = [ #:nodoc:
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
        install_finders if Interlock.config[:with_finders]
      end
  
      # 
      # Configure memcached for this app.
      #
      def install_memcached
        Interlock.config[:namespace] << "-#{RAILS_ENV}"
  
        unless defined? Object::CACHE
        
          # Give people a choice of client, even though I don't like conditional dependencies.
          klass = case Interlock.config[:client]
            when 'memcached'
              Memcached::Rails
            when 'memcache-client'              
              raise ConfigurationError, "You have the Ruby-MemCache gem installed. Please uninstall Ruby-MemCache, or otherwise guarantee that memcache-client will load instead." if MemCache.constants.include?('SVNURL')
              MemCache              
            else
              raise ConfigurationError, "Invalid client name '#{Interlock.config[:client]}'"
          end
          
          Object.const_set('CACHE', 
            klass.new(
              Interlock.config[:servers], 
              Interlock.config.slice(*CLIENT_KEYS)
            )
          )
          
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
          
          def read(*args)
            get args.first
          end
          
          def write(name, content, options = {})             
            set(name, 
              content, 
              options.is_a?(Hash) ? options[:ttl] : Interlock.config[:ttl] )
          end          
        end  
              
      end
      
      #
      # Configure Rails to use the memcached store for fragments, and optionally, sessions.
      #    
      def install_fragments
        # Memcached fragment caching is mandatory        
        ActionView::Helpers::CacheHelper.class_eval do
          def cache(name, options = nil, &block)
            # Things explode if options does not default to nil
            RAILS_DEFAULT_LOGGER.debug "** fragment #{name} stored via obsolete cache() call"
            @controller.cache_erb_fragment(block, name, options)
          end
        end                
        ActionController::Base.fragment_cache_store = CACHE
  
        # Sessions are optional
        if Interlock.config[:sessions]
          ActionController::Base.session_store = :mem_cache_store
          ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.update 'cache' => CACHE      
        end      
      end    
      
      #
      # Configure ActiveRecord#find caching.
      #
      def install_finders
        # RAILS_DEFAULT_LOGGER.warn "** using interlock finder caches"      
        class << ActiveRecord::Base
          private      
          alias :find_via_db :find
          remove_method :find
          
          public
          include Interlock::Finders
        end        
      end

    end      
  end
end