
module Interlock
  module Lock
  
    #
    # Try to acquire a global lock from memcached for a particular key. 
    # If successful, yield and set the key to the return value, then release
    # the lock. 
    #
    # Based on http://rubyurl.com/Sw7 , which I partially wrote.
    #
  
    def lock(key, lock_expiry = 30, retries = 5)
      retries.times do |count|
      
        # We have to be compatible with both client APIs. Eventually we can use Memcached#cas 
        # for this.        
        begin
          response = CACHE.add("lock:#{key}", "Locked by #{Process.pid}", lock_expiry)
          # Nil is a successful response for Memcached 0.11, so we'll simulate the MemCache API.          
          if response == true or response == nil
            response = "STORED\r\n"
          end
        rescue Memcached::NotStored # do nothing
        rescue Memcached::Errors
          # if memcached raises one of these errors, lets assume the servers down
          return nil
        rescue Object => e
          # Catch exceptions from Memcached without setting response.
        end
        
        if response == "STORED\r\n"
          begin
            value = yield(CACHE.get(key))
            CACHE.set(key, value)
            return value
          ensure 
            CACHE.delete("lock:#{key}")
          end
        else
          sleep((2**count) / 2.0)
        end
      end
      raise ::Interlock::LockAcquisitionError, "Couldn't acquire lock for #{key}"
    end
    
    # update key content and release lock 
   	def update_and_unlock(key) 
   	  begin 
   	    value = yield(CACHE.get(key)) 
   	    CACHE.set(key, value) 
   	    return value 
   	  ensure  
   	    CACHE.delete("lock:#{key}") 
   	  end 
   	end 
   	
   	# locks cache key for a pending update, returning true if lock successful and false if not 
   	def lock_for_update(key, lock_expiry = 30) 
   	  begin 
   	    CACHE.add("lock:#{key}", "Locked by #{Process.pid}", lock_expiry) 
   	    response = true 
   	  rescue Object => e 
   	    response = false 
   	  end 
   	  response 
   	end
  end
end
