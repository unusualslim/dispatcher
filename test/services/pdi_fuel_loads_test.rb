require 'test_helper'
require 'minitest/mock'

class PdiFuelLoadsTest < ActiveSupport::TestCase
  def loads_xml = file_fixture('pdi_fuel_loads.xml').read

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    PdiOrderApiImportService.call(file_fixture('pdi_truck_freight.xml').read)
    CustomerOrder.update_all(invoice_date: Date.new(2026, 10, 7)) # rubocop:disable Rails/SkipsModelValidations
  end

  test 'imports each load with its business date, purchase lines and load charges; a second import changes nothing' do
    assert_equal [2, 0, 0], PdiFuelLoads::Import.call(loads_xml).to_h.values_at(:created, :updated, :unchanged)
    load = PdiFuelLoad.find_by!(load_no: '34779')
    assert_equal [Date.new(2026, 10, 2), Date.new(2026, 10, 1), '1514', '21', %w[OD-1 OD-2]],
                 [load.business_date, load.lift_date, load.carrier_id, load.vehicle_id, load.order_nos]
    assert_equal([['Freight', '4868', '450.0'], ['Freight', '4868', '300.0'], ['FPLSPLIT', nil, '75.0']],
                 load.items.map { |item| item.values_at('charge', 'bol', 'amount') })
    assert_equal '34845 / 34763C', PdiFuelLoad.find_by!(load_no: '34845').label

    assert_equal [0, 0, 2], PdiFuelLoads::Import.call(loads_xml).to_h.values_at(:created, :updated, :unchanged)
  end

  test 'by load business date: purchase freight from the loads, sale from their orders, charges once' do
    PdiFuelLoads::Import.call(loads_xml)
    params = { from: '2026-10-01', to: '2026-10-31', date_basis: 'business', carrier_id: '1514' }

    truck = Reports::FreightByTruck.new(params).rows.sole
    assert_equal ['Truck 21 PB 490', 3, 4000], truck.values_at(:truck, :orders, :gallons)
    assert_equal [550, 75, 1000], truck.values_at(:cost_freight, :cost_charges, :sale).map(&:to_d),
                 '750 on the load − 200 correction; split fee once; sale from OD-1 and OD-2'

    rows = Reports::FreightDetail.new(params).rows
    correction = rows.find { |row| row[:bol] == '9690310C' }
    assert_equal [Date.new(2026, 10, 1), '34845 / 34763C', 'OD-9C', nil, -200],
                 correction.values_at(:business_date, :load, :order_no, :order, :cost)
    fee = rows.find { |row| row[:charge] == 'FPLSPLIT' }
    assert_equal [75, nil], [fee[:cost], fee[:order_no]]

    september = Reports::FreightDetail.new(params.merge(from: '2026-09-01', to: '2026-09-30')).rows
    assert_empty september, 'the September delivery counts on its October business date'
  end

  test 'by invoice date, lines show the load and business date of their order' do
    PdiFuelLoads::Import.call(loads_xml)
    row = Reports::FreightDetail.new({ from: '2026-10-01', to: '2026-10-31' }).rows
                                .find { |r| r[:order_no] == 'OD-1' && r[:charge] == 'FPLSPLIT' }
    assert_equal [Date.new(2026, 10, 2), '34779 · 1 of 2'], row.values_at(:business_date, :load)
  end

  # Records each GetFuelLoads window and returns the fixture.
  class FakePdi
    attr_reader :windows

    def initialize(xml)
      @xml = xml
      @windows = []
    end

    def fuel_loads(statuses:, from:, to:)
      @windows << [from, to, statuses]
      Nokogiri::XML(@xml).root
    end
  end

  test 'the sync job fetches the window month by month and imports the loads' do
    pdi = FakePdi.new(loads_xml)
    PdiWebService.stub(:configured?, true) do
      PdiWebService.stub(:new, pdi) do
        PdiFuelLoadSyncJob.perform_now(from: Date.new(2026, 9, 1), to: Date.new(2026, 10, 15))
      end
    end

    assert_equal([[Date.new(2026, 9, 1), Date.new(2026, 10, 1)], [Date.new(2026, 10, 2), Date.new(2026, 10, 15)]],
                 pdi.windows.map { |from, to, _| [from, to] })

    log = SyncLog.for_process(PdiFuelLoadSyncJob::PROCESS_NAME).first
    assert_equal ['success', 2, 2, nil], [log.status, log.records_created, log.records_skipped, log.file_content]
  end
end
