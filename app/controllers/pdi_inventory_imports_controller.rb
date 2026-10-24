class PdiInventoryImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'PDI FI Inventory Import'.freeze

  def new
    @logs = SyncLog.for_process(PROCESS_NAME).limit(10)
  end

  def create
    file = params[:file]
    redirect_to new_pdi_inventory_import_path, alert: 'Please select a file.' and return unless file.present?

    log = start_log(file)
    results = PdiInventoryImportService.new(file, current_user).import
    log.update!(status: 'success', completed_at: Time.current, records_updated: results[:updated],
                records_skipped: results[:skipped], warnings: PdiFuelInventorySyncJob.warnings(results))

    redirect_to new_pdi_inventory_import_path, notice: summary(results)
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    redirect_to new_pdi_inventory_import_path, alert: "Import failed: #{e.message}"
  end

  private

  def start_log(file)
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current,
                          file_name: file.original_filename, file_content: Base64.strict_encode64(file.read),
                          file_binary: true)
    file.rewind
    log
  end

  def summary(results)
    notice = "FI inventory synced: #{results[:updated]} product(s) updated"
    notice += ", #{results[:skipped]} skipped" if results[:skipped].positive?
    warnings = PdiFuelInventorySyncJob.warnings(results)
    warnings ? "#{notice}. #{warnings.tr("\n", ' ')}" : "#{notice}."
  end
end
