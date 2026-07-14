class PurchaseOrderImportsController < ApplicationController
  before_action :require_admin!

  def new
  end

  def preview
    unless params[:file].present?
      redirect_to new_purchase_order_imports_path, alert: "Please select a file." and return
    end

    @vendor_groups   = PdiWarehouseTransactionImportService.new(params[:file]).preview
    @import_status   = params[:import_status].presence_in(PurchaseOrder::STATUSES) || 'received'
    @existing_vendors = Vendor.order(:name).pluck(:name, :id)

    ext = File.extname(params[:file].original_filename).downcase.presence_in(['.xls', '.xlsx']) || '.xls'
    tmp = Tempfile.new(['po_import', ext], binmode: true)
    tmp.write(params[:file].read)
    tmp.flush
    session[:po_import_tmp_path] = tmp.path
    ObjectSpace.undefine_finalizer(tmp)
  end

  def create
    unless session[:po_import_tmp_path].present? && File.exist?(session[:po_import_tmp_path].to_s)
      redirect_to new_purchase_order_imports_path, alert: "Import session expired. Please re-upload the file." and return
    end

    file               = File.open(session[:po_import_tmp_path])
    selected_refs   = params[:selected_refs]&.to_unsafe_h&.keys
    vendor_actions  = params[:vendor_actions]&.to_unsafe_h || {}  # { pdi_id => "create"|"skip"|existing_vendor_id }
    import_status   = params[:import_status].presence_in(PurchaseOrder::STATUSES) || 'received'

    result = PdiWarehouseTransactionImportService.new(file).import(
      selected_references: selected_refs,
      vendor_actions:      vendor_actions,
      import_status:       import_status
    )

    file.close
    File.delete(session[:po_import_tmp_path]) rescue nil
    session.delete(:po_import_tmp_path)

    msg = "Import complete: #{result[:created]} POs created, #{result[:skipped]} skipped."
    msg += " #{result[:errors]} could not be imported." if result[:errors] > 0

    redirect_to purchase_orders_path(status: 'received'), notice: msg
  end
end
