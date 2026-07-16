class PurchaseOrderImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'PDI PO Import'.freeze

  def new
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
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
    session[:po_import_tmp_path]       = tmp.path
    session[:po_import_file_name]      = params[:file].original_filename
    ObjectSpace.undefine_finalizer(tmp)
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_purchase_order_imports_path, alert: "File not available." if log.file_content.blank?

    ext = File.extname(log.file_name.to_s).downcase
    mime = ext == '.xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'application/vnd.ms-excel'
    send_data Base64.strict_decode64(log.file_content),
              type:        mime,
              disposition: "attachment; filename=\"#{log.file_name}\""
  end

  def create
    unless session[:po_import_tmp_path].present? && File.exist?(session[:po_import_tmp_path].to_s)
      redirect_to new_purchase_order_imports_path, alert: "Import session expired. Please re-upload the file." and return
    end

    file               = File.open(session[:po_import_tmp_path])
    selected_refs   = params[:selected_refs]&.to_unsafe_h&.keys
    vendor_actions  = params[:vendor_actions]&.to_unsafe_h || {}  # { pdi_id => "create"|"skip"|existing_vendor_id }
    import_status   = params[:import_status].presence_in(PurchaseOrder::STATUSES) || 'received'

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    session[:po_import_file_name] || File.basename(session[:po_import_tmp_path]),
      file_content: Base64.strict_encode64(File.binread(session[:po_import_tmp_path])),
      file_binary:  true,
      started_at:   Time.current
    )

    begin
      result = PdiWarehouseTransactionImportService.new(file).import(
        selected_references: selected_refs,
        vendor_actions:      vendor_actions,
        import_status:       import_status
      )

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_created: result[:created],
        records_skipped: result[:skipped],
        warnings:        result[:warnings].any? ? result[:warnings].join("\n") : nil
      )
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      file.close
      File.delete(session[:po_import_tmp_path]) rescue nil
      session.delete(:po_import_tmp_path)
      session.delete(:po_import_file_name)
      redirect_to new_purchase_order_imports_path, alert: "Import failed: #{e.message}" and return
    end

    file.close
    File.delete(session[:po_import_tmp_path]) rescue nil
    session.delete(:po_import_tmp_path)
    session.delete(:po_import_file_name)

    msg = "Import complete: #{result[:created]} POs created, #{result[:skipped]} skipped."
    msg += " #{result[:errors]} could not be imported — see warnings below." if result[:errors] > 0

    redirect_to new_purchase_order_imports_path, notice: msg
  end
end
