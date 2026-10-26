require 'test_helper'
require 'minitest/mock'

# PdiOrders::Feed, PdiOrders::StatusCheck and PdiOrderApiSyncJob against a fake PDI client.
class PdiOrderApiSyncTest < ActiveSupport::TestCase
  class FakePdi
    attr_reader :calls

    def initialize(statuses: {}, fail_on: nil)
      @statuses = statuses
      @fail_on = fail_on
      @calls = []
    end

    def warehouse_orders(**filter)
      orders('PDIWarehouseOrders', 'PDIWarehouseOrder', :warehouse, filter)
    end

    def fuel_orders(**filter)
      orders('PDIFuelOrders', 'PDIFuelOrder', :fuel, filter)
    end

    def order_status(order_no)
      @statuses.fetch(order_no, 99)
    end

    private

    # One order per warehouse status 1 call and per open-fuel call; everything else empty.
    def orders(root, tag, type, filter)
      @calls << [type, filter]
      raise PdiWebService::Error, 'HTTP 409' if @fail_on == [type, filter[:statuses]]

      xml = "<#{root}>"
      xml += "<#{tag}><OrderNo>OD-W1</OrderNo>#{order_xml}</#{tag}>" if type == :warehouse && filter[:statuses] == [1]
      if type == :fuel && filter[:from].nil?
        xml += "<#{tag}><OrderNo>OD-F1</OrderNo><OrderStatus>5</OrderStatus>#{order_xml}</#{tag}>"
      end
      Nokogiri::XML("#{xml}</#{root}>").root
    end

    def order_xml
      '<DestinationType>1</DestinationType><CustomerID>9</CustomerID><CustomerLocationID>1</CustomerLocationID>' \
        '<CustomerDescription>Acme</CustomerDescription><ShipToDescription>Acme Yard</ShipToDescription>' \
        '<WarehouseDetail><OrderedProductID>X1</OrderedProductID><OrderedQuantity>2</OrderedQuantity>' \
        '<UnitPrice>3.50</UnitPrice></WarehouseDetail>'
    end
  end

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  test 'feed asks warehouse one status at a time, dates only finished statuses, and survives a failed call' do
    pdi = FakePdi.new(fail_on: [:warehouse, [6]])
    feed = PdiOrders::Feed.new(pdi, today: Date.new(2026, 10, 26))
    doc = Nokogiri::XML(feed.fetch)

    warehouse = pdi.calls.select { |type, _| type == :warehouse }
    assert_equal(PdiOrders::Statuses::WAREHOUSE, warehouse.map { |_, f| f[:statuses].sole })
    dated = pdi.calls.select { |_, f| f[:from] }.map { |type, f| [type, f[:statuses]] }
    assert_equal [[:warehouse, [6]], [:warehouse, [7]], [:warehouse, [8]], [:warehouse, [9]], [:warehouse, [11]],
                  [:fuel, [6, 7, 8, 9, 11]]], dated
    assert_equal [Date.new(2026, 8, 27), Date.new(2027, 10, 26)], pdi.calls.find { |_, f|
      f[:from]
    }.last.values_at(:from, :to)

    assert_equal ['warehouse orders (status 6): HTTP 409'], feed.errors
    assert_equal %w[OD-W1 OD-F1], doc.xpath('//OrderNo').map(&:text)
    assert_equal '1', doc.at('//PDIWarehouseOrder').parent.parent['status']
  end

  test 'status check updates open orders PDI did not send, skipping the ones it did' do
    location = Location.create!(company_name: 'Yard', location_category_id: 2)
    billed = CustomerOrder.create!(external_order_no: 'OD-1', order_status: 'open_order', location: location)
    gone = CustomerOrder.create!(external_order_no: 'OD-2', order_status: 'quote', location: location)
    sent = CustomerOrder.create!(external_order_no: 'OD-3', order_status: 'open_order', location: location)
    CustomerOrder.create!(external_order_no: 'OD-4', order_status: 'billed', location: location)

    pdi = FakePdi.new(statuses: { 'OD-1' => 6, 'OD-3' => 8 })
    result = PdiOrders::StatusCheck.new(pdi, skip: ['OD-3']).run

    assert_equal [2, 1, 1], [result.checked, result.updated, result.not_found]
    assert_equal %w[billed Billed], [billed.reload.order_status, billed.odor_status]
    assert_equal 'quote', gone.reload.order_status
    assert_equal 'open_order', sent.reload.order_status
  end

  test 'job imports the feed and records the run, keeping the file only when something failed' do
    pdi = FakePdi.new
    with_env('PDI_API_PARTNER_ID' => 'p', 'PDI_API_PASSWORD' => 'x') do
      PdiWebService.stub(:new, pdi) { PdiOrderApiSyncJob.perform_now }
    end

    log = SyncLog.for_process(PdiOrderApiSyncJob::PROCESS_NAME).first
    assert_equal ['success', 2, nil], [log.status, log.records_created, log.file_content]
    assert_equal 'released_for_billing', CustomerOrder.find_by!(external_order_no: 'OD-F1').order_status
    assert_equal 'open_order', CustomerOrder.find_by!(external_order_no: 'OD-W1').order_status
  end

  test 'a run with a failed call keeps its feed file on the log' do
    with_env('PDI_API_PARTNER_ID' => 'p', 'PDI_API_PASSWORD' => 'x') do
      PdiWebService.stub(:new, FakePdi.new(fail_on: [:warehouse, [6]])) { PdiOrderApiSyncJob.perform_now }
    end

    log = SyncLog.for_process(PdiOrderApiSyncJob::PROCESS_NAME).first
    assert_includes Zlib.gunzip(Base64.strict_decode64(log.file_content)), '<OrderNo>OD-F1</OrderNo>'
    assert_match(/Fetch failed: warehouse orders \(status 6\): HTTP 409/, log.warnings)
  end

  test 'order filter matches PDI schema layout' do
    xml = PdiWebService::OrderFilter.xml('PDIGetFuelOrders', statuses: [6, 7], from: Date.new(2026, 9, 1),
                                                             to: Date.new(2026, 9, 30), order_no: 'OD-1&2')

    assert_equal '<PDIGetFuelOrdersFilter><PDIGetFuelOrdersInput xmlns=""><StatusToInclude><Status>6</Status>' \
                 '<Status>7</Status></StatusToInclude><RecordsToInclude>3</RecordsToInclude>' \
                 '<SchedDelivDateTimeFrom>2026-09-01T00:00:00</SchedDelivDateTimeFrom>' \
                 '<SchedDelivDateTimeTo>2026-09-30T23:59:59</SchedDelivDateTimeTo><OrderNo>OD-1&amp;2</OrderNo>' \
                 '</PDIGetFuelOrdersInput></PDIGetFuelOrdersFilter>', xml
  end

  private

  def with_env(vars)
    saved = ENV.to_h.slice(*vars.keys)
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    vars.each_key { |k| ENV[k] = saved[k] }
  end
end
