
# Setup integration system for the integration suite

Dir.chdir "#{File.dirname(__FILE__)}/integration/app/" do
  system "memcached -p 43042 &"
  system "memcached -p 43043 &"
  
  Dir.chdir "vendor/plugins" do
    system "rm interlock; ln -s ../../../../../ interlock"
  end
  
  system "rake db:create"
  system "rake db:migrate"
  system "rake db:fixtures:load"
end
