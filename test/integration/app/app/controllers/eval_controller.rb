class EvalController < ApplicationController

  def index
    render :text => eval(CGI.unescape(params['string'])).inspect
  end
  
end
