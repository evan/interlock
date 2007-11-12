
class Hash
  alias :fetch_safely :[]

  def value_for_indifferent_key(key)
    fetch_safely(key) or fetch_safely(key.to_s) or fetch_safely(key.to_sym)
  end
  
  alias :v :value_for_indifferent_key
  
  def indifferentiate!
    class << self
      def [](key); value_for_indifferent_key(key); end
    end        
    self
  end

  def indifferentiate
    self.dup.indifferentiate!    
  end   
end

class String
  def field(i)
    split(":")[i]
  end
  
  def escape_tag_fragment
    gsub(':', ';').gsub(/[^\w\d;]/, '_')
  end
end

class Object
  def to_interlock_tag
    string = to_s
    string = "empty_string" if string.empty? 
    string.escape_tag_fragment
  end
end

class NilClass
  def to_interlock_tag
    "untagged".escape_tag_fragment
  end
end

class ActiveRecord::Base
  def to_interlock_tag
    "#{self.class.name}-#{self.id}".escape_tag_fragment
  end
end
