require 'base64'
require 'zlib'

module PdiOrders
  # Fills customer orders' truck/freight columns (TruckFreight) from the order feeds saved on SyncLogs, oldest
  # first so the latest copy of each order wins. Only those columns are written.
  class TruckFreightBackfill
    PROCESSES = [PdiOrderApiSyncJob::PROCESS_NAME, PdiOrderApiFullSyncJob::PROCESS_NAME].freeze

    # Number of orders updated.
    def run
      latest = {}
      saved_feeds.find_each(batch_size: 20) { |log| read(log, latest) }
      latest.sum do |order_no, attrs|
        CustomerOrder.where(external_order_no: order_no).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    private

    def saved_feeds
      SyncLog.where(process_name: PROCESSES).where.not(file_content: nil)
    end

    def read(log, latest)
      doc = Nokogiri::XML(Zlib.gunzip(Base64.strict_decode64(log.file_content)))
      doc.xpath('//PDIFuelOrder | //PDIWarehouseOrder').each do |node|
        latest[OrderNode.new(node).order_no] = TruckFreight.new(node).attrs
      end
    rescue Zlib::Error, ArgumentError => e
      Rails.logger.warn "[TruckFreightBackfill] SyncLog #{log.id}: #{e.message}"
    end
  end
end
