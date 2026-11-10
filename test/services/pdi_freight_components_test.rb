require 'test_helper'

# PDI's freight in detail (FPS_FREIGHT_DETAIL_*.csv) splitting the freight reports' line freight into its rules.
class PdiFreightComponentsTest < ActiveSupport::TestCase
  def path = file_fixture('pdi_freight_detail.csv').to_s

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    PdiOrderApiImportService.call(file_fixture('pdi_truck_freight.xml').read)
    CustomerOrder.update_all(invoice_date: Date.new(2026, 10, 7)) # rubocop:disable Rails/SkipsModelValidations
    PdiFuelLoads::Import.call(file_fixture('pdi_fuel_loads.xml').read)
  end

  test 'imports each component; a later file replaces a line\'s components' do
    result = PdiFreightComponents::Import.call(path)
    assert_equal [6, 0, []], [result.created, result.skipped, result.warnings]
    fsc = PdiFreightComponent.find_by!(source: 'load', component_key: '9002')
    assert_equal ['34779', 'OD-1', '4868', '901', '501', 'FPLFSC', 2, true, true, 49.96],
                 fsc.values_at(:load_no, :order_no, :bol, :product, :line_key, :charge, :rule_type, :purchase,
                               :sale, :amount)
    assert_not PdiFreightComponent.find_by!(component_key: '9004').purchase

    Tempfile.create(%w[freight .csv]) do |file|
      file.write(File.readlines(path).values_at(0, 1).join)
      file.flush
      PdiFreightComponents::Import.call(file.path)
    end
    assert_equal %w[9001], PdiFreightComponent.where(line_key: '501').pluck(:component_key)
    assert_equal 6 - 3, PdiFreightComponent.count
  end

  test 'by invoice date: line freight splits into base rate and surcharge, totals unchanged' do
    PdiFreightComponents::Import.call(path)
    params = { from: '2026-10-01', to: '2026-10-31' }

    rows = Reports::FreightDetail.new(params).rows.select { |row| row[:order_no] == 'OD-1' }
    assert_equal([['Sale', 'FPLFSC', 50], ['Sale', 'Freight', 550], ['Purchase', 'FPS-TP-DEF PER MILE', 400.04],
                  ['Purchase', 'FPLFSC', 49.96], ['Purchase', 'FPLSPLIT', 37.5]],
                 rows.map { |row| [row[:side], row[:charge], (row[:sale].nonzero? || row[:cost]).to_f] },
                 'the 2¢ rounding goes on the base rate; FPLSPLIT stays the load charge; the override is not a line')

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
                 'OD-1 400.04 + OD-2 200 + 100 not explained − 200 correction; split fee + FPLFSC'

    od2 = Reports::FreightDetail.new(params).rows.select { |row| row[:order_no] == 'OD-2' && row[:side] == 'Purchase' }
    assert_equal([['TA-TP-DEF-NUTAUG', 200], ['Freight', 100]], od2.map { |row| [row[:charge], row[:cost].to_f] })
  end
end
