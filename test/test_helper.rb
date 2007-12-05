
require 'rubygems'
require 'test/unit'
require 'activesupport'

$rcov = ENV['RCOV']
require 'ruby-debug' unless $rcov

HERE = File.dirname(__FILE__)
$LOAD_PATH << HERE

require 'integration/app/config/environment'
