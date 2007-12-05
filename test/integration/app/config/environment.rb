
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|

  config.action_controller.session = {:session_key => '_app_session', :secret => '22cde4d5c1a61ba69a817953'}
    
  #  config.to_prepare do     
  #    RAILS_DEFAULT_LOGGER.info "** interlock dependencies:"
  #    Interlock.dependencies.each do |klass, list|
  #      RAILS_DEFAULT_LOGGER.info "    #{klass}:"
  #      list.each do |key, scope|
  #        RAILS_DEFAULT_LOGGER.info "      #{key} => #{scope.inspect}"
  #      end
  #    end
  #  end
  
end

ENV['RAILS_ASSET_ID'] = Time.now.to_i.to_s
