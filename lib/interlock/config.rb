
module Interlock

  DEFAULTS = {
    :ttl => 1.day,
    :namespace => 'app',
    :servers => ['localhost:11211']
  }    

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
          config = YAML.load_file(CONFIG_FILE)
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
          klass = MemCacheWithConsistentHashing rescue MemCache
          Object.const_set('CACHE', klass.new(Interlock.config))
          CACHE.servers = Array(Interlock.config[:servers])
        end
        
        class << CACHE
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