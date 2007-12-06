
$VERBOSE = nil
require 'rubygems'
require 'test/unit'
require 'multi_rails_init'

$rcov = ENV['RCOV']
require 'ruby-debug' unless $rcov

HERE = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << HERE

require 'integration/app/config/environment'
