class WarehouseTransactionImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Warehouse Transaction Import'.freeze

  def new
    @existing_count = InventoryTransaction.where("notes LIKE ?", "[PDI Historical Import]%").count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def create
    file = params[:file]
    return redirect_to new_warehouse_transaction_import_path, alert: "Please select a file." unless file

    unless file.original_filename.downcase.end_with?('.xls', '.xlsx')
      return redirect_to new_warehouse_transaction_import_path, alert: "File must be an XLS or XLSX file."
    end

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    file.original_filename,
      file_content: Base64.strict_encode64(file.read),
      file_binary:  true,
      started_at:   Time.current
    )

    begin
      result = WarehouseTransactionImportService.call(file.path)

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
