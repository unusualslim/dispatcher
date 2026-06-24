require 'net/ftp'

class PdiVendorSyncJob < ApplicationJob
  queue_as :default

  PROCESS_NAME = 'PDI Vendor Sync'
  VENDOR_FILE  = ENV.fetch('PDI_FTP_VENDOR_FILE', '/Imports/AP Vendor List.csv')

  def perform
    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      file_name:    File.basename(VENDOR_FILE),
      status:       'running',
      started_at:   Time.current
    )

    csv_content = download_from_ftp
    result      = PdiVendorImportService.call(csv_content)

    log.update!(
      file_content: csv_content,
      status:          'success',
      completed_at:    Time.current,
      records_created: result.created,
      records_updated: result.updated,
      records_skipped: result.skipped,
      warnings:        result.errors.any? ? result.errors.join("\n") : nil
    )

    Rails.logger.info "[PdiVendorSyncJob] Sync complete — " \
      "created: #{result.created}, updated: #{result.updated}, skipped: #{result.skipped}"
  rescue => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiVendorSyncJob] Failed: #{e.message}"
    raise
  end

  private

  def download_from_ftp
    host     = ENV.fetch('PDI_FTP_HOST')
    user     = ENV.fetch('PDI_FTP_USER')
    password = ENV.fetch('PDI_FTP_PASSWORD')

    content = StringIO.new
    Net::FTP.open(host, username: user, password: password) do |ftp|
      ftp.passive = true
      ftp.retrbinary("RETR #{VENDOR_FILE}", Net::FTP::DEFAULT_BLOCKSIZE) do |chunk|
        content << chunk
      end
    end
    content.string
  end
end
