require 'net/ftp'

class PdiVendorSyncJob < ApplicationJob
  queue_as :default

  VENDOR_FILE = ENV.fetch('PDI_FTP_VENDOR_FILE', '/LoadNTrucks Imports/AP Vendor List.csv')

  def perform
    csv_content = download_from_ftp
    result = PdiVendorImportService.call(csv_content)

    Rails.logger.info "[PdiVendorSyncJob] Sync complete — " \
      "created: #{result.created}, updated: #{result.updated}, skipped: #{result.skipped}"

    result.errors.each do |err|
      Rails.logger.warn "[PdiVendorSyncJob] Row error: #{err}"
    end
  rescue => e
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
