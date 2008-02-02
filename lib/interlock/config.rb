
module Interlock

  DEFAULTS = {
    :ttl => 1.day,
    :namespace => 'app',
    :servers => ['127.0.0.1:11211'],
    :client => 'memcache-client'
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
        
        memcached!
        rails!
      end
  
      # 
      # Configure memcached for this app.
      #
      def memcached!
        Interlock.config[:namespace] << "-#{RAILS_ENV}"
  
        unless defined? Object::CACHE
        
          # Give people a choice of client, even though I don't like conditional dependencies.
          klass = case Interlock.config[:client]
            when 'memcached'
              require 'memcached'
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
        end
        
        # Add the fragment cache and lock APIs to the cache singleton.
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
      def rails!
        # Memcached fragment caching is mandatory
        ActionController::Base.fragment_cache_store = CACHE
  
        if Interlock.config[:sessions]
          ActionController::Base.session_store = :mem_cache_store
          ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.update 'cache' => CACHE      
        end      
      end    

    end      
  end
end