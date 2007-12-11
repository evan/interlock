
require 'dispatcher'

Dispatcher.to_prepare(:reset_interlock_memory_cache) do 
  Interlock.local_cache = ActionController::Base::MemoryStore.new
end