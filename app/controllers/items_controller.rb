class ItemsController < ApplicationController
  def search
    @search = Search.build params
    session[:last_query] = request.url
  end

  def show
    @item = Item.find(params[:id]).first
    raise ActionController::RoutingError.new('Not Found') unless @item
  end
end