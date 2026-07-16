class WarehouseTransactionImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Warehouse Transaction Import'.freeze

  def new
    @existing_count = InventoryTransaction.where("notes LIKE ?", "[PDI Historical Import]%").count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_warehouse_transaction_import_path, alert: "Please select a file." unless file
    return redirect_to new_warehouse_transaction_import_path, alert: "File must be an XLS or XLSX file." unless file.original_filename.downcase.end_with?('.xls', '.xlsx')

    ext = File.extname(file.original_filename).downcase
    tmp = Tempfile.new(['wt_import', ext], binmode: true)
    tmp.write(file.read)
    tmp.flush
    session[:wt_import_tmp_path]   = tmp.path
    session[:wt_import_file_name]  = file.original_filename
    ObjectSpace.undefine_finalizer(tmp)

    @rows              = WarehouseTransactionImportService.new(tmp.path).preview
    @import_count      = @rows.count { |r| r.action == :import }
    @skip_no_product   = @rows.count { |r| r.action == :skip_no_product }
    @skip_duplicate    = @rows.count { |r| r.action == :skip_duplicate }
  end

  def create
    unless session[:wt_import_tmp_path].present? && File.exist?(session[:wt_import_tmp_path].to_s)
      return redirect_to new_warehouse_transaction_import_path, alert: "Import session expired. Please re-upload the file."
    end

    file_path = session[:wt_import_tmp_path]
    file_name = session[:wt_import_file_name] || File.basename(file_path)

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    file_name,
      file_content: Base64.strict_encode64(File.binread(file_path)),
      file_binary:  true,
      started_at:   Time.current
    )

    begin
      result = WarehouseTransactionImportService.call(file_path)

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_created: result.imported,
        records_skipped: result.skipped_no_product + result.skipped_unknown_type + result.skipped_duplicate,
        warnings:        result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.imported} imported, " \
                "#{result.skipped_no_product} skipped (product not found), " \
                "#{result.skipped_duplicate} duplicates skipped."
      summary += " #{result.errors.count} rows had errors." if result.errors.any?

      flash[:notice] = summary
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      File.delete(file_path) rescue nil
      session.delete(:wt_import_tmp_path)
      session.delete(:wt_import_file_name)
    end

    redirect_to new_warehouse_transaction_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_warehouse_transaction_import_path, alert: "File not available." if log.file_content.blank?

    send_data Base64.strict_decode64(log.file_content),
              type:        'application/vnd.ms-excel',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
