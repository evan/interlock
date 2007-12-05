
module Interlock
end

unless defined? MemCache or defined? MemCacheWithConsistentHashing
  raise "Interlock requires the memcache-client gem"
end

require 'interlock/core_extensions'
require 'interlock/config'
require 'interlock/rails'
require 'interlock/interlock'

unless ActionController::Base.perform_caching
  RAILS_DEFAULT_LOGGER.warn "** interlock warning; config.perform_caching == false"
end

Interlock::Config.run!
