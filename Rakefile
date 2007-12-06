
require 'echoe'
require 'load_multi_rails_rake_tasks'

Echoe.new("interlock") do |p|
  p.project = "fauna"
  p.summary = "An optimal efficiency caching plugin for Rails."
  p.url = "http://blog.evanweaver.com/files/doc/fauna/interlock/"  
  p.docs_host = "blog.evanweaver.com:~/www/bax/public/files/doc/"  
  p.dependencies = "memcache_client >=1.5.0"
  p.test_pattern = ["test/integration/*.rb", "test/unit/*.rb"]
end
