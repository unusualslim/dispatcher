require 'base64'
require 'zlib'

# Pulls fuel and warehouse orders from the PDI web service (PdiOrders::Feed), imports them
# (PdiOrderApiImportService), then re-checks open orders PDI didn't send (PdiOrders::StatusCheck).
# Replaces PdiOrderSyncJob's FTP orders.xls. Off until scheduled.
class PdiOrderApiSyncJob < ApplicationJob
  queue_as :default

  PROCESS_NAME = 'PDI Order API Sync'.freeze
  FILE_NAME = 'pdi_orders.xml.gz'.freeze

  # Imports a saved feed (job, or `rake pdi:reimport_orders`) and records the outcome on its SyncLog.
  def self.import(xml, log, client: nil, fetch_errors: [])
    result = PdiOrderApiImportService.call(xml)
    checks = client && PdiOrders::StatusCheck.new(client, skip: result.seen).run
    log.update!(status: 'success', completed_at: Time.current, records_created: result.created,
                records_updated: result.updated + checks&.updated.to_i, records_skipped: result.unchanged,
                warnings: warnings(result, checks, fetch_errors))
    result
  end

  def self.warnings(result, checks, fetch_errors)
    lines = fetch_errors.map { |e| "Fetch failed: #{e}" } + result.errors
    if checks
      lines << "Status check: #{checks.checked} open orders checked, #{checks.updated} updated, " \
               "#{checks.not_found} not found in PDI"
      lines.concat(checks.errors)
    end
    lines.join("\n").presence
  end

  def perform
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)
    unless PdiWebService.configured?
      return log.update!(status: 'skipped', completed_at: Time.current,
                         error_message: 'PDI web service credentials are not set')
    end

    sync(log)
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiOrderApiSyncJob] Failed: #{e.message}"
    raise
  end

  private

  # The feed is saved before importing: PDI won't send these orders again, so a failed import
  # can be re-run from the SyncLog.
  def sync(log)
    client = PdiWebService.new
    feed = PdiOrders::Feed.new(client)
    xml = feed.fetch
    log.update!(file_name: FILE_NAME, file_content: Base64.strict_encode64(Zlib.gzip(xml)), file_binary: true)
    self.class.import(xml, log, client: client, fetch_errors: feed.errors)
  end
end
