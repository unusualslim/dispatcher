class PdiInventoryImportsController < ApplicationController
  before_action :require_admin!

  def new
  end

  def create
    unless params[:file].present?
      redirect_to new_pdi_inventory_import_path, alert: "Please select a file." and return
    end

    results = PdiInventoryImportService.new(params[:file], current_user).import
    notice  = "PDI sync complete: #{results[:updated]} product(s) updated"
    notice += ", #{results[:skipped]} skipped (no PDI Tank ID match)" if results[:skipped] > 0
    notice += "." + (results[:errors].any? ? " Errors: #{results[:errors].join('; ')}" : "")

    redirect_to new_pdi_inventory_import_path, notice: notice
  rescue => e
    redirect_to new_pdi_inventory_import_path, alert: "Import failed: #{e.message}"
  end
end
