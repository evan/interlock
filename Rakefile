
require 'echoe'

Echoe.new("interlock") do |p|
  p.project = "fauna"
  p.summary = "A Rails plugin for maintainable and high-efficiency caching."
  p.url = "http://blog.evanweaver.com/files/doc/fauna/interlock/"  
  p.docs_host = "blog.evanweaver.com:~/www/bax/public/files/doc/"  
  p.dependencies = "memcache_client >=1.5.0"
  p.test_pattern = ["test/integration/*.rb", "test/unit/*.rb"]
  p.rdoc_pattern = ["README", "CHANGELOG", "TODO", "LICENSE", "lib/interlock/memcached.rb", "lib/interlock/interlock.rb", "lib/interlock/action_controller.rb", "lib/interlock/active_record.rb", "lib/interlock/action_view.rb", "lib/interlock/config.rb"]
end

desc "Run all the tests in production and development mode both"
task "test_all" do
  STDERR.puts "#{'='*80}\nDevelopment mode\n#{'='*80}"
  system("rake test:multi_rails:all")

  ENV['PRODUCTION'] = '1'
  STDERR.puts "#{'='*80}\nProduction mode\n#{'='*80}"
  system("rake test:multi_rails:all")
end

task "tail" do
  log = "test/integration/app/log/development.log"
  system("touch #{log} && tail -f #{log} | grep interlock")
end