class WarehousesController < ApplicationController
  before_action :require_any_access!
  def set
    session[:warehouse_id] = params[:id].presence
    redirect_to params[:return_to].presence || authenticated_root_path
  end
end
