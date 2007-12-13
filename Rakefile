
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

task :setup do
  Echoe.silence { system("ruby test/setup.rb") }
end
task :test => :setup 

desc "Run all the tests in production and development mode both"
task "test_all" do
  STDERR.puts "#{'='*80}\nDevelopment mode\n#{'='*80}"
  system("rake test:multi_rails:all")

  ENV['PRODUCTION'] = '1'
  STDERR.puts "#{'='*80}\nProduction mode\n#{'='*80}"
  system("rake test:multi_rails:all")
end
