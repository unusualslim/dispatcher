class InventoryImportsController < ApplicationController
  def new
  end

  def preview
    unless params[:file].present?
      redirect_to new_inventory_import_path, alert: "Please select a file." and return
    end

    @product_type = params[:product_type].presence_in(%w[raw_material finished_good]) || "raw_material"
    @rows = InventoryImportService.new(params[:file]).preview
    @update_count = @rows.count { |r| r.action == :update }
    @create_count = @rows.count { |r| r.action == :create }

    # Store file temporarily for the confirm step
    tmp = Tempfile.new(['inventory_import', '.xlsx'], binmode: true)
    tmp.write(params[:file].read)
    tmp.flush
    session[:import_tmp_path]   = tmp.path
    session[:import_product_type] = @product_type
    ObjectSpace.undefine_finalizer(tmp)  # prevent auto-deletion before confirm
  end

  def create
    unless session[:import_tmp_path].present? && File.exist?(session[:import_tmp_path].to_s)
      redirect_to new_inventory_import_path, alert: "Import session expired. Please re-upload the file." and return
    end

    file         = File.open(session[:import_tmp_path])
    selected     = params[:selected_parts]&.keys
    product_type = session[:import_product_type].presence_in(%w[raw_material finished_good]) || "raw_material"

    counts = InventoryImportService.new(file).import(selected_part_numbers: selected, product_type: product_type)
    file.close
    File.delete(session[:import_tmp_path]) rescue nil
    session.delete(:import_tmp_path)
    session.delete(:import_product_type)

    redirect_to new_inventory_import_path,
                notice: "Import complete: #{counts[:updated]} updated, #{counts[:created]} created, #{counts[:skipped]} skipped."
  end
end
