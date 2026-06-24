class PdiVendorSyncJob < ApplicationJob
  include PdiFtpConcern
  queue_as :default

  PROCESS_NAME = 'PDI Vendor Sync'
  FTP_DIR      = ENV.fetch('PDI_FTP_VENDOR_DIR', '/Imports')

  FILE_PATTERNS = [
    /ap.?vendor/i,
    /ap.?vend/i,
    /vendor/i,
    /vend/i,
  ].freeze

  def perform
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)

    filename    = nil
    csv_content = nil

    ftp_connect do |ftp|
      filename    = ftp_find_file(ftp, FTP_DIR, ['.csv'], FILE_PATTERNS)
      csv_content = ftp_download_text(ftp, filename)
    end

    result = PdiVendorImportService.call(csv_content)

    ftp_connect { |ftp| ftp_delete(ftp, filename) }

    log.update!(
      file_name:       filename,
      file_content:    csv_content,
      status:          'success',
      completed_at:    Time.current,
      records_created: result.created,
      records_updated: result.updated,
      records_skipped: result.skipped,
      warnings:        result.errors.any? ? result.errors.join("\n") : nil
    )

    Rails.logger.info "[PdiVendorSyncJob] Sync complete (#{filename}) — " \
      "created: #{result.created}, updated: #{result.updated}, skipped: #{result.skipped}"
  rescue => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiVendorSyncJob] Failed: #{e.message}"
    raise
  end
end
