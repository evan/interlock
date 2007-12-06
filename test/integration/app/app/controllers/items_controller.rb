class ItemsController < ApplicationController

  before_filter :related

  def index
    behavior_cache do
      @items = Item.find(:all)
    end
    render :action => 'list'
  end
  
  def show
    behavior_cache Item => :id do
      @item = Item.find(params['id'])
    end
  end
  
  def recent
    behavior_cache nil, :tag => [:seconds] do
      @items = Item.find(:all, :conditions => ['updated_at >= ?', params['seconds'].to_i.ago])
    end
  end
  
  private
  
  def related
    behavior_cache :ignore => :all, :tag => 'related' do
      @related = "Delicious cake"
    end
  end
  
end
