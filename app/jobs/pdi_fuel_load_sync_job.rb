require 'base64'
require 'zlib'

# Nightly: every PDI fuel load (all carriers) delivered in the last LOOKBACK_DAYS, imported into PdiFuelLoad
# for the freight reports' load business date basis. GetFuelLoads filters on delivery date only, and PDI
# corrections (34763C…) keep the original delivery date with a later business date, hence the long window.
# Fetched month by month with RecordsToInclude 3 (all), which leaves PDI's sent flags alone.
# The feed stays on the SyncLog only when something failed.
class PdiFuelLoadSyncJob < ApplicationJob
  queue_as :default

  PROCESS_NAME = 'PDI Fuel Load Sync'.freeze
  LOOKBACK_DAYS = 120
  CHUNK_DAYS = 31

  # from / to: delivery dates (default: the last LOOKBACK_DAYS through tomorrow).
  def perform(from: nil, to: nil)
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)
    return skip(log) unless PdiWebService.configured?

    sync(log, *window(from, to))
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiFuelLoadSyncJob] Failed: #{e.message}"
    raise
  end

  private

  def window(from, to)
    [from&.to_date || (Date.current - LOOKBACK_DAYS), to&.to_date || (Date.current + 1)]
  end

  def skip(log)
    log.update!(status: 'skipped', completed_at: Time.current, error_message: 'PDI web service credentials are not set')
  end

  def sync(log, from, to)
    xml, errors = fetch(PdiWebService.new(read_timeout: 300), from, to)
    result = PdiFuelLoads::Import.call(xml)
    log.update!(status: errors.empty? ? 'success' : 'failed', completed_at: Time.current,
                records_created: result.created, records_updated: result.updated, records_skipped: result.unchanged,
                warnings: errors.join("\n").presence)
    save_feed(log, xml) if errors.any?
  end

  # <PDIFuelLoadFeed><Batch from to><PDIFuelLoads>… per chunk; a failed chunk is noted and the rest still run.
  def fetch(client, from, to)
    doc = Nokogiri::XML::Document.new
    doc.root = doc.create_element('PDIFuelLoadFeed', from: from.iso8601, to: to.iso8601)
    errors = chunks(from, to).filter_map { |start, finish| add_batch(client, doc, start, finish) }
    [doc.to_xml, errors]
  end

  # nil, or the error for a failed chunk.
  def add_batch(client, doc, start, finish)
    batch = doc.root.add_child(doc.create_element('Batch', from: start.iso8601, to: finish.iso8601))
    batch.add_child(client.fuel_loads(statuses: PdiOrders::Statuses::FUEL, from: start, to: finish).dup(1))
    nil
  rescue *PdiWebService::FAILURES => e
    "#{start}–#{finish}: #{e.message}"
  end

  def chunks(from, to)
    (from..to).each_slice(CHUNK_DAYS).map { |days| [days.first, days.last] }
  end

  def save_feed(log, xml)
    log.update!(file_name: 'pdi_fuel_loads.xml.gz', file_content: Base64.strict_encode64(Zlib.gzip(xml)),
                file_binary: true)
  end
end
