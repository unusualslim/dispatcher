require 'base64'

# Daily: pulls PDI's FI (fuel) Inventory Report from FTP and syncs tank stock by product and site.
class PdiFuelInventorySyncJob < ApplicationJob
  include PdiFtpConcern
  queue_as :default

  PROCESS_NAME  = 'PDI Fuel Inventory Sync'.freeze
  FTP_DIR       = ENV.fetch('PDI_FTP_FUEL_DIR', '/Imports')
  FILE_PATTERNS = [/\bfi.?inventory/i].freeze

  def self.warnings(results)
    list = []
    list << "Not in the app: #{results[:unmatched_products].join(', ')}" if results[:unmatched_products].any?
    sites = results[:unmatched_sites]
    list << "No location with PDI site number: #{sites.join(', ')}" if sites.any?
    list.concat(results[:errors])
    list.join("\n").presence
  end

  def perform
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)
    sync(log)
  rescue PdiFtpConcern::NoFileFound => e
    log&.update!(status: 'skipped', completed_at: Time.current, error_message: e.message)
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiFuelInventorySyncJob] Failed: #{e.message}"
    raise
  end

  private

  def sync(log)
    filename, tempfile = download
    raw_bytes = tempfile.read
    tempfile.rewind

    results = PdiInventoryImportService.new(tempfile).import
    ftp_connect { |ftp| ftp_delete(ftp, filename) }
    record_success(log, filename, raw_bytes, results)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def record_success(log, filename, raw_bytes, results)
    log.update!(file_name: filename, file_content: Base64.strict_encode64(raw_bytes), file_binary: true,
                status: 'success', completed_at: Time.current, records_updated: results[:updated],
                records_skipped: results[:skipped], warnings: self.class.warnings(results))
  end

  def download
    ftp_connect do |ftp|
      filename = ftp_find_file(ftp, FTP_DIR, ['.xls', '.xlsx', '.csv'], FILE_PATTERNS)
      return [filename, ftp_download_tempfile(ftp, filename)]
    end
  end
end
