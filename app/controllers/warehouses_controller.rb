class WarehousesController < ApplicationController
  def set
    session[:warehouse_id] = params[:id].presence
    redirect_back fallback_location: authenticated_root_path
  end
end
