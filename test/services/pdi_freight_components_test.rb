require 'test_helper'

# PDI's freight in detail (FPS_FREIGHT_DETAIL_*.csv) splitting the freight reports' line freight into its rules.
class PdiFreightComponentsTest < ActiveSupport::TestCase
  PART = %w[amount base].freeze

  def path = file_fixture('pdi_freight_detail.csv').to_s

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    PdiOrderApiImportService.call(file_fixture('pdi_truck_freight.xml').read)
    CustomerOrder.update_all(invoice_date: Date.new(2026, 10, 7)) # rubocop:disable Rails/SkipsModelValidations
    PdiFuelLoads::Import.call(file_fixture('pdi_fuel_loads.xml').read)
  end

  test 'imports each component; a later file replaces a line\'s components' do
    result = PdiFreightComponents::Import.call(path)
    assert_equal [5, 1, ['1 order/load-level charges left to the API']],
                 [result.created, result.skipped, result.warnings]
    fsc = PdiFreightComponent.find_by!(source: 'load', component_key: '9002')
    assert_equal ['34779', 'OD-1', '4868', '901', '501', 'FPLFSC', 2, true, true, 49.96],
                 fsc.values_at(:load_no, :order_no, :bol, :product, :line_key, :charge, :rule_type, :purchase,
                               :sale, :amount)
    assert_not PdiFreightComponent.find_by!(component_key: '9005').purchase

    Tempfile.create(%w[freight .csv]) do |file|
      file.write(File.readlines(path).values_at(0, 1).join)
      file.flush
      PdiFreightComponents::Import.call(file.path)
    end
    assert_equal %w[9001], PdiFreightComponent.where(line_key: '501').pluck(:component_key)
    assert_equal 5 - 2, PdiFreightComponent.count
  end

  test 'by invoice date: line freight splits into base rate and surcharge, totals unchanged' do
    PdiFreightComponents::Import.call(path)
    params = { from: '2026-10-01', to: '2026-10-31' }

    rows = Reports::FreightDetail.new(params).rows.select { |row| row[:order_no] == 'OD-1' }
    assert_equal([['Sale', 'FPLFSC', 50], ['Sale', 'Freight', 550], ['Purchase', 'FPS-TP-DEF PER MILE', 400.04],
                  ['Purchase', 'FPLFSC', 49.96], ['Purchase', 'FPLSPLIT', 37.5]],
                 rows.map { |row| [row[:side], row[:charge], (row[:sale].nonzero? || row[:cost]).to_f] },
                 'the 2¢ rounding goes on the base rate; FPLSPLIT stays the load charge')

    truck = Reports::FreightByTruck.new(params).rows.first
    assert_equal [950, 50, 700.04, 124.96], truck.values_at(:sale_freight, :sale_charges, :cost_freight,
                                                            :cost_charges).map(&:to_f)
    assert_equal [1000, 825], truck.values_at(:sale, :cost).map(&:to_f)
  end

  test 'by load business date: the load lines split the same way, gallons counted once' do
    PdiFreightComponents::Import.call(path)
    params = { from: '2026-10-01', to: '2026-10-31', date_basis: 'business', carrier_id: '1514' }

    truck = Reports::FreightByTruck.new(params).rows.sole
    assert_equal [4000, 500.04, 124.96, 625],
                 truck.values_at(:gallons, :cost_freight, :cost_charges, :cost).map(&:to_f),
                 'OD-1 400.04 + OD-2 override 300 − 200 correction; split fee + FPLFSC'

    od2 = Reports::FreightDetail.new(params).rows.select { |row| row[:order_no] == 'OD-2' && row[:side] == 'Purchase' }
    assert_equal([['Total Freight Override', 300]], od2.map { |row| [row[:charge], row[:cost].to_f] })
  end

  test 'lines sharing order, BOL and product each take their own PDI line, matched by freight total' do
    line = { source: 'load', order_no: 'OD-5', bol: '77', product: '901', purchase: true, sale: true }
    [['L1', 100, 'BASE', 0, 90], ['L1', 100, 'FPLFSC', 2, 10], ['L2', 50, 'BASE', 0, 45], ['L2', 50, 'FPLFSC', 2, 5],
     ['L3', -50, 'BASE', 0, -45], ['L3', -50, 'FPLFSC', 2, -5]]
      .each_with_index do |(key, total, charge, type, amount), i|
        PdiFreightComponent.create!(line.merge(component_key: i, line_key: key, line_freight: total, charge: charge,
                                               rule_type: type, amount: amount))
      end
    breakdown = Reports::FreightEntries::Breakdown.new(['OD-5'])
    item = { 'side' => 'purchase', 'charge' => 'Freight', 'bol' => '77', 'product' => '901' }
    split = ->(amount) { breakdown.split(item.merge('amount' => amount), 'OD-5', []).map { |p| p.values_at(*PART) } }

    assert_equal [['45.0', true], ['5.0', false]], split.call('50.0')
    assert_equal [['90.0', true], ['10.0', false]], split.call('100.0')
    assert_equal [['-45.0', true], ['-5.0', false]], split.call('-50.0'), 'a correction splits the same way'
  end
end
