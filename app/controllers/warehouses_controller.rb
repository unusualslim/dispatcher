class WarehousesController < ApplicationController
  def set
    session[:warehouse_id] = params[:id].presence
    redirect_back fallback_location: root_path
  end
end
