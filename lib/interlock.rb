
module Interlock
end

unless defined? MemCache or defined? MemCacheWithConsistentHashing
  raise "Interlock requires the memcache-client gem"
end

if MemCache.constants.include?('SVNURL')
  raise "You have the Ruby-MemCache gem installed. Interlock uses memcache-client. Please uninstall Ruby-MemCache, or otherwise guarantee that memcache-client will load instead."
end

require 'interlock/core_extensions'
require 'interlock/config'
require 'interlock/interlock'
require 'interlock/memcached'
require 'interlock/action_controller'
require 'interlock/action_view'
require 'interlock/active_record'

unless ActionController::Base.perform_caching
  RAILS_DEFAULT_LOGGER.warn "** interlock warning; config.perform_caching == false"
end

Interlock::Config.run!
