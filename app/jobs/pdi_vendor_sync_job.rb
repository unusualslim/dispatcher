require 'net/ftp'

class PdiVendorSyncJob < ApplicationJob
  queue_as :default

  PROCESS_NAME = 'PDI Vendor Sync'
  FTP_DIR      = ENV.fetch('PDI_FTP_VENDOR_DIR', '/Imports')

  # Patterns tried in order — first match wins
  VENDOR_FILE_PATTERNS = [
    /vendor/i,
    /ap.?vendor/i,
    /ap.?vend/i,
    /vend/i,
  ].freeze

  def perform
    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      started_at:   Time.current
    )

    filename, csv_content = download_from_ftp
    result = PdiVendorImportService.call(csv_content)

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

  private

  def download_from_ftp
    host     = ENV.fetch('PDI_FTP_HOST')
    user     = ENV.fetch('PDI_FTP_USER')
    password = ENV.fetch('PDI_FTP_PASSWORD')

    content  = StringIO.new
    filename = nil

    Net::FTP.open(host, username: user, password: password) do |ftp|
      ftp.passive = true
      ftp.chdir(FTP_DIR)

      csv_files = ftp.nlst.select { |f| f.downcase.end_with?('.csv') }
      raise "No CSV files found in #{FTP_DIR}" if csv_files.empty?

      filename = find_vendor_file(csv_files)
      raise "No vendor CSV found in #{FTP_DIR} (files: #{csv_files.join(', ')})" unless filename

      ftp.retrbinary("RETR #{filename}", Net::FTP::DEFAULT_BLOCKSIZE) do |chunk|
        content << chunk
      end
    end

    [filename, content.string]
  end

  def find_vendor_file(files)
    VENDOR_FILE_PATTERNS.each do |pattern|
      match = files.find { |f| File.basename(f, '.csv').match?(pattern) }
      return match if match
    end
    nil
  end
end
