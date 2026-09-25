require 'net/ftp'

class PdiOrderSyncJob < ApplicationJob
  include PdiFtpConcern
  queue_as :default

  PROCESS_NAME = 'PDI Order Sync'
  FTP_DIR      = ENV.fetch('PDI_FTP_ORDER_DIR', '/EnterpriseData/Reports')

  FILE_PATTERNS = [
    /loadntrucks.*order.*export/i,
    /order.*export/i,
    /loadntrucks/i,
  ].freeze

  def perform
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)

    filename = nil
    tempfile = nil

    ftp_connect do |ftp|
      ftp.chdir(FTP_DIR)
      matches = ftp.nlst
                   .select { |f| f.downcase.end_with?('.pdf') }
                   .select { |f| FILE_PATTERNS.any? { |pat| File.basename(f).match?(pat) } }
                   .sort

      raise PdiFtpConcern::NoFileFound, "No matching PDF found in #{FTP_DIR}" if matches.empty?

      filename = matches.last  # most recent by sorted filename (timestamp suffix)
      tempfile = ftp_download_tempfile(ftp, filename)
      ftp_delete(ftp, filename)
    end

    result = CustomerOrderImportService.call(tempfile.path)

    log.update!(
      file_name:       filename,
      status:          'success',
      completed_at:    Time.current,
      records_created: result.created,
      records_updated: result.updated,
      records_skipped: result.skipped,
      warnings:        result.errors.any? ? result.errors.join("\n") : nil
    )

    Rails.logger.info "[PdiOrderSyncJob] Sync complete (#{filename}) — " \
      "created: #{result.created}, updated: #{result.updated}, skipped: #{result.skipped}"
  rescue PdiFtpConcern::NoFileFound => e
    log&.update!(status: 'skipped', completed_at: Time.current, error_message: e.message)
    Rails.logger.info "[PdiOrderSyncJob] No file found — skipping"
  rescue => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiOrderSyncJob] Failed: #{e.message}"
    raise
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
