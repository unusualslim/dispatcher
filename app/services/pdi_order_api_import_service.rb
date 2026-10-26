# Imports a PdiOrders::Feed document (fuel + warehouse orders from the PDI web service) into
# CustomerOrders. Replaces the FTP orders.xls import (CustomerOrderImportService).
class PdiOrderApiImportService
  Result = Struct.new(:created, :updated, :unchanged, :errors, :seen, keyword_init: true)

  def self.call(xml)
    new(xml).run
  end

  def initialize(xml)
    @doc = Nokogiri::XML(xml)
  end

  def run
    @result = Result.new(created: 0, updated: 0, unchanged: 0, errors: [], seen: Set.new)
    @doc.xpath('/PDIOrderFeed/Batch').each { |batch| import_batch(batch) }
    @result
  end

  private

  # A warehouse batch holds one status (its orders don't carry one); fuel orders carry <OrderStatus>.
  def import_batch(batch)
    status = batch['status'].to_s.split.first if batch['type'] == 'warehouse'
    batch.xpath('*/PDIWarehouseOrder | */PDIFuelOrder').each { |node| import(PdiOrders::OrderNode.new(node, status)) }
  end

  def import(order)
    @result[PdiOrders::OrderWriter.new(order).save!] += 1
    @result.seen << order.order_no
  rescue StandardError => e
    @result.errors << "#{order.order_no}: #{e.message}"
  end
end
