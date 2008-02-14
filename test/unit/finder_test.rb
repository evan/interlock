
require "#{File.dirname(__FILE__)}/../test_helper"
require 'fileutils'

class FinderTest < Test::Unit::TestCase

  LOG = "#{HERE}/integration/app/log/development.log"     
  
  ### Finder caching tests
  
  def test_find_without_cache
    Item.find(1, {})
    assert_no_match(/model.*Item:find:1:default is loading from the db/, log)
  end
  
  def test_find
    assert_equal Item.find(1, {}),
      Item.find(1)
    assert_match(/model.*Item:find:1:default is loading from the db/, log)

    assert_equal Item.find(1, {}),
      Item.find(1)
    assert_match(/model.*Item:find:1:default is loading from memcached/, log)
  end
  
  def test_find_with_array
    assert_equal Item.find([1, 2], {}),
      Item.find([1, 2])
    assert_match(/model.*Item:find:1:default is loading from the db/, log)
    assert_match(/model.*Item:find:2:default is loading from the db/, log)

    assert_equal Item.find([1, 2], {}),
      Item.find([1, 2])
    assert_match(/model.*Item:find:1:default is loading from memcached/, log)
    assert_match(/model.*Item:find:2:default is loading from memcached/, log)    
  end 
  
  def test_find_raise
    assert_raises(ActiveRecord::RecordNotFound) do
      Item.find(44)
    end  
  end
    
  def test_find_with_array_raise
    assert_raises(ActiveRecord::RecordNotFound) do
      # Once from the DB
      Item.find([1, 2, 44])
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      # Once from Memcached
      Item.find([1, 2, 44])
    end  
  end

  def test_invalidate
    Item.find(1).save!
    truncate
    Item.find(1)
    assert_match(/model.*Item:find:1:default is loading from the db/, log)
    Item.find(1)
    assert_match(/model.*Item:find:1:default is loading from memcached/, log)  
  end  

  def test_find_all_by_id
    assert_equal Item.find_all_by_id(44, {}), 
      Item.find_all_by_id(44)
    assert_equal Item.find_all_by_id([1,2], {}), 
      Item.find_all_by_id([1,2])
    assert_equal Item.find_all_by_id(1, 2, {}), 
      Item.find_all_by_id(1, 2)
  end

  def test_find_by_id
    assert_equal Item.find_by_id(44, {}), 
      Item.find_by_id(44)
    assert_equal Item.find_by_id([1,2], {}), 
      Item.find_by_id([1,2])
    assert_equal Item.find_by_id(1, 2, {}), 
      Item.find_by_id(1, 2)
  end
    
  ### Support methods
  
  def setup
    # Change the asset ID; has a similar effect to flushing memcached
    @old_asset_id = ENV['RAILS_ASSET_ID']
    ENV['RAILS_ASSET_ID'] = rand.to_s
    truncate    
  end
  
  def teardown
    # Restore the asset id
    ENV['RAILS_ASSET_ID'] = @old_asset_id
  end

  def truncate
    system("> #{LOG}")
  end
  
  def log
    File.open(LOG, 'r') do |f|
      f.read
    end
  end  
end