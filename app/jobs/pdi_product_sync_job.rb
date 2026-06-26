require 'base64'

class PdiProductSyncJob < ApplicationJob
  include PdiFtpConcern
  queue_as :default

  PROCESS_NAME = 'PDI Product Sync'
  FTP_DIR      = ENV.fetch('PDI_FTP_PRODUCT_DIR', '/Imports')

  FILE_PATTERNS = [
    /loadntrucks.?current.?inventory/i,
    /current.?inventory/i,
    /inventory/i,
  ].freeze

  def perform
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)

    filename = nil
    tempfile = nil
    raw_bytes = nil

    ftp_connect do |ftp|
      filename  = ftp_find_file(ftp, FTP_DIR, ['.xls', '.xlsx'], FILE_PATTERNS)
      tempfile  = ftp_download_tempfile(ftp, filename)
      raw_bytes = tempfile.read
      tempfile.rewind
    end

    result = InventoryImportService.new(tempfile).import

    ftp_connect { |ftp| ftp_delete(ftp, filename) }

    log.update!(
      file_name:       filename,
      file_content:    Base64.strict_encode64(raw_bytes),
      file_binary:     true,
      status:          'success',
      completed_at:    Time.current,
      records_created: result[:created],
      records_updated: result[:updated],
      records_skipped: result[:skipped]
    )

    Rails.logger.info "[PdiProductSyncJob] Sync complete (#{filename}) — " \
      "created: #{result[:created]}, updated: #{result[:updated]}, skipped: #{result[:skipped]}"
  rescue PdiFtpConcern::NoFileFound => e
    log&.update!(status: 'skipped', completed_at: Time.current, error_message: e.message)
    Rails.logger.info "[PdiProductSyncJob] No file found — skipping"
  rescue => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiProductSyncJob] Failed: #{e.message}"
    raise
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
