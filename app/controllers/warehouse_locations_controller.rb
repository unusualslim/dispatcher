class WarehouseLocationsController < ApplicationController
  before_action :require_admin!

  def edit
    @locations = Location.where(location_category_id: 1).order(:company_name)
  end

  def update
    # params[:location_ids] is an array of IDs that should be in the dropdown
    enabled_ids = Array(params[:location_ids]).map(&:to_i)

    Location.where(location_category_id: 1).find_each do |loc|
      loc.update_column(:show_in_warehouse_dropdown, enabled_ids.include?(loc.id))
    end

    redirect_to edit_warehouse_locations_path, notice: "Warehouse dropdown locations updated."
  end
end
