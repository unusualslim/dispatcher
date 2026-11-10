require 'test_helper'

class FreightByTruckTest < ActiveSupport::TestCase
  # Two orders on one load of truck 21 (FPLSPLIT $75 on both), one no-truck order with a sale charge.
  def feed
    file_fixture('pdi_truck_freight.xml').read
  end

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    assert_empty PdiOrderApiImportService.call(feed).errors
  end

  test 'the import records truck, driver and each freight item' do
    order = CustomerOrder.find_by!(external_order_no: 'OD-1')
    assert_equal ['21', 'Truck 21 PB 490', 'Neal Harris', 3000],
                 [order.pdi_vehicle_id, order.pdi_vehicle, order.pdi_driver, order.pdi_gallons]
    assert_equal([%w[sale Freight 600.0], %w[purchase Freight 450.0], %w[purchase FPLSPLIT 75.0]],
                 order.pdi_freight_items.map { |item| item.values_at('side', 'charge', 'amount') })
    assert_equal '5307', order.pdi_freight_items.last['load']
    assert_equal([%w[purchase Freight 100.0], %w[sale OWI 100.0]],
                 CustomerOrder.find_by!(external_order_no: 'OD-3').pdi_freight_items
                              .map { |item| item.values_at('side', 'charge', 'amount') })
  end

  test 'freight detail lists each item, splitting a load charge over its orders' do
    rows = Reports::FreightDetail.new({ from: '2026-10-01', to: '2026-10-31' }).rows

    split = rows.select { |row| row[:charge] == 'FPLSPLIT' }
    assert_equal([[37.5, '5307 (1 of 2)']] * 2, split.map { |row| [row[:cost].to_f, row[:load]] })
    surcharge = rows.find { |row| row[:charge] == 'OWI' }
    assert_equal ['No truck (no carrier)', 'Sale', 100], surcharge.values_at(:truck, :side, :sale)
    freight = rows.find { |row| row[:order_no] == 'OD-1' && row[:side] == 'Purchase' && row[:charge] == 'Freight' }
    assert_equal [3000, 0.15, 450], freight.values_at(:quantity, :rate, :cost)
  end

  test 'freight by truck rolls the detail up, counting a load charge once' do
    report = Reports::FreightByTruck.new({ from: '2026-10-01', to: '2026-10-31' })
    truck, no_truck = report.rows

    assert_equal ['Truck 21 PB 490', 'Neal Harris', 2, 5000], truck.values_at(:truck, :drivers, :orders, :gallons)
    assert_equal [1000, 0, 750, 75, 175], truck.values_at(:sale_freight, :sale_charges, :cost_freight, :cost_charges,
                                                          :margin)
    assert_equal [0, 100, 100], no_truck.values_at(:sale_freight, :sale_charges, :cost)
    assert_equal [1100, 925], report.totals.values_at(:sale, :cost)
  end

  test 'the backfill fills truck freight from saved feeds' do
    CustomerOrder.update_all(pdi_vehicle_id: nil, pdi_gallons: nil, pdi_freight_items: []) # rubocop:disable Rails/SkipsModelValidations
    SyncLog.create!(process_name: PdiOrderApiSyncJob::PROCESS_NAME, status: 'success', started_at: Time.current,
                    file_content: Base64.strict_encode64(Zlib.gzip(feed)), file_binary: true)

    assert_equal 3, PdiOrders::TruckFreightBackfill.new.run
    order = CustomerOrder.find_by!(external_order_no: 'OD-2')
    assert_equal ['21', 2000, 3], [order.pdi_vehicle_id, order.pdi_gallons, order.pdi_freight_items.size]
  end
end
