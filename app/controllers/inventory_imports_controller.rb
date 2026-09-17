class InventoryImportsController < ApplicationController
  before_action :require_admin!

  def new
  end

  def preview
    unless params[:file].present?
      redirect_to new_inventory_import_path, alert: "Please select a file." and return
    end

    service      = InventoryImportService.new(params[:file])
    @rows        = service.preview
    @sites       = service.sites
    @warehouses  = Location.where(location_category_id: 1, show_in_warehouse_dropdown: true).order(:company_name)
    @update_count = @rows.count { |r| r.action == :update }
    @create_count = @rows.count { |r| r.action == :create }

    # Store file temporarily for the confirm step (preserve extension for format detection)
    ext = File.extname(params[:file].original_filename).downcase.presence_in(['.xls', '.xlsx']) || '.xlsx'
    tmp = Tempfile.new(['inventory_import', ext], binmode: true)
    tmp.write(params[:file].read)
    tmp.flush
    session[:import_tmp_path]  = tmp.path
    session[:import_sites]     = @sites.map { |s| [s[:code], s[:name]] }
    ObjectSpace.undefine_finalizer(tmp)  # prevent auto-deletion before confirm
  end

  def create
    unless session[:import_tmp_path].present? && File.exist?(session[:import_tmp_path].to_s)
      redirect_to new_inventory_import_path, alert: "Import session expired. Please re-upload the file." and return
    end

    file     = File.open(session[:import_tmp_path])
    selected = params[:selected_parts]&.keys

    # Build site_code => Location map from submitted site_locations param
    site_location_map = {}
    (params[:site_locations] || {}).each do |site_code, location_id|
      next if location_id.blank?
      loc = Location.find_by(id: location_id)
      site_location_map[site_code] = loc if loc
    end

    counts = InventoryImportService.new(file).import(
      selected_part_numbers: selected,
      site_location_map:     site_location_map
    )
    file.close
    File.delete(session[:import_tmp_path]) rescue nil
    session.delete(:import_tmp_path)
    session.delete(:import_sites)

    mapped_labels = site_location_map.map { |code, loc| "#{code} → #{loc.company_name}" }.join(", ")
    notice = "Import complete: #{counts[:updated]} updated, #{counts[:created]} created, #{counts[:skipped]} skipped."
    notice += " Warehouses: #{mapped_labels}." if mapped_labels.present?

    redirect_to new_inventory_import_path, notice: notice
  end
end
