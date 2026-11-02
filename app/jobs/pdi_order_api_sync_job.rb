require 'base64'
require 'zlib'

# Pulls the orders that are new or changed in PDI since it last sent them (PdiOrders::Feed :changes) and
# imports them (PdiOrderApiImportService). Runs every 15 minutes; PdiOrderApiFullSyncJob fetches everything
# nightly. Asking PDI for only the changes keeps its order audit logs from filling with a "fetched" line
# per order per run. Replaces PdiOrderSyncJob's FTP orders.xls.
class PdiOrderApiSyncJob < ApplicationJob
  queue_as :default

  PROCESS_NAME = 'PDI Order API Sync'.freeze
  MODE = :changes
  FILE_NAME = 'pdi_orders.xml.gz'.freeze

  # Imports a saved feed (job, or `rake pdi:reimport_orders`) and records the outcome on its SyncLog.
  def self.import(xml, log, client: nil, fetch_errors: [])
    result = PdiOrderApiImportService.call(xml)
    checks = client && PdiOrders::StatusCheck.new(client, skip: result.seen).run
    merges = PdiOrders::LinkedOrderMerge.new.run
    log.update!(status: 'success', completed_at: Time.current, records_created: result.created,
                records_updated: result.updated + checks&.updated.to_i, records_skipped: result.unchanged,
                warnings: warnings(result, checks, fetch_errors, merges))
    result
  end

  def self.warnings(result, checks, fetch_errors, merges)
    lines = fetch_errors.map { |e| "Fetch failed: #{e}" } + result.errors + merge_lines(merges)
    if checks
      lines << "Status check: #{checks.checked} open orders checked, #{checks.updated} updated, " \
               "#{checks.not_found} not found in PDI"
      lines.concat(checks.errors)
    end
    lines.join("\n").presence
  end

  def self.merge_lines(merges)
    merged = merges.merged.any? ? ["Merged app orders into their PDI orders: #{merges.merged.join(', ')}"] : []
    merged + merges.errors
  end

  def perform
    log = SyncLog.create!(process_name: self.class::PROCESS_NAME, status: 'running', started_at: Time.current)
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

  # The feed is saved before importing so a failed import can be inspected or re-run from its SyncLog
  # (`rake pdi:reimport_orders`). PDI sends a change only once, so changes runs keep it; clean full runs
  # drop it (they fetch everything again, ~300 KB gzipped).
  def sync(log)
    client = PdiWebService.new
    feed = PdiOrders::Feed.new(client, mode: self.class::MODE)
    xml = feed.fetch
    save_feed(log, xml)
    result = self.class.import(xml, log, client: (client if full?), fetch_errors: feed.errors)
    log.update!(file_name: nil, file_content: nil) if full? && result.errors.empty? && feed.errors.empty?
  end

  def save_feed(log, xml)
    log.update!(file_name: FILE_NAME, file_content: Base64.strict_encode64(Zlib.gzip(xml)), file_binary: true)
  end

  # Only a full run knows which open orders PDI no longer sends, so only it runs the status check.
  def full?
    self.class::MODE == :full
  end
end
