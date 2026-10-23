class PdiPurchaseOrderImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'PDI Purchase Order Import'.freeze

  def new
    @po_count = PurchaseOrder.count
    @pdi_count = PurchaseOrder.where(trigger_type: 'pdi_import').count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_pdi_purchase_order_import_path, alert: 'Please select a file.' unless file

    unless file.original_filename.downcase.end_with?('.csv')
      return redirect_to new_pdi_purchase_order_import_path,
                         alert: 'File must be a CSV file.'
    end

    tmp = Tempfile.new(['pdi_po_import', '.csv'])
    tmp.binmode
    tmp.write(file.read)
    tmp.flush
    session[:pdi_po_import_tmp_path] = tmp.path
    session[:pdi_po_import_file_name] = file.original_filename
    ObjectSpace.undefine_finalizer(tmp)

    @rows = PdiPurchaseOrderImportService.new(tmp.path).preview
    @create_count = @rows.count { |r| r.action == :create }
    @skip_exists_count = @rows.count { |r| r.action == :skip_exists }
  end

  def create
    unless session[:pdi_po_import_tmp_path].present? && File.exist?(session[:pdi_po_import_tmp_path].to_s)
      return redirect_to new_pdi_purchase_order_import_path, alert: 'Import session expired. Please re-upload the file.'
    end

    file_path = session[:pdi_po_import_tmp_path]
    file_name = session[:pdi_po_import_file_name] || File.basename(file_path)

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status: 'running',
      file_name: file_name,
      file_binary: false,
      started_at: Time.current
    )

    begin
      result = PdiPurchaseOrderImportService.call(file_path)

      log.update!(
        status: 'success',
        completed_at: Time.current,
        records_created: result.created,
        records_skipped: result.skipped_exists + result.skipped_no_vendor,
        warnings: result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.created} purchase orders created."
      summary += " #{result.skipped_exists} already imported." if result.skipped_exists > 0
      summary += " #{result.errors.count} warnings." if result.errors.any?

      flash[:notice] = summary
    rescue StandardError => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      File.delete(file_path) rescue nil
      session.delete(:pdi_po_import_tmp_path)
      session.delete(:pdi_po_import_file_name)
    end

    redirect_to new_pdi_purchase_order_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_pdi_purchase_order_import_path, alert: 'File not available.' if log.file_content.blank?

    send_data log.file_content,
              type: 'text/csv',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
