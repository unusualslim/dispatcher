class InventoryImportsController < ApplicationController
  before_action :require_admin!
  def new
  end

  def preview
    unless params[:file].present?
      redirect_to new_inventory_import_path, alert: "Please select a file." and return
    end

    @rows = InventoryImportService.new(params[:file]).preview
    @update_count = @rows.count { |r| r.action == :update }
    @create_count = @rows.count { |r| r.action == :create }

    # Store file temporarily for the confirm step (preserve extension for format detection)
    ext = File.extname(params[:file].original_filename).downcase.presence_in(['.xls', '.xlsx']) || '.xlsx'
    tmp = Tempfile.new(['inventory_import', ext], binmode: true)
    tmp.write(params[:file].read)
    tmp.flush
    session[:import_tmp_path] = tmp.path
    ObjectSpace.undefine_finalizer(tmp)  # prevent auto-deletion before confirm
  end

  def create
    unless session[:import_tmp_path].present? && File.exist?(session[:import_tmp_path].to_s)
      redirect_to new_inventory_import_path, alert: "Import session expired. Please re-upload the file." and return
    end

    file         = File.open(session[:import_tmp_path])
    selected = params[:selected_parts]&.keys

    counts = InventoryImportService.new(file).import(selected_part_numbers: selected)
    file.close
    File.delete(session[:import_tmp_path]) rescue nil
    session.delete(:import_tmp_path)

    redirect_to new_inventory_import_path,
                notice: "Import complete: #{counts[:updated]} updated, #{counts[:created]} created, #{counts[:skipped]} skipped."
  end
end
