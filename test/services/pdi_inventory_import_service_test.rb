require 'test_helper'

class PdiInventoryImportServiceTest < ActiveSupport::TestCase
  fixtures :locations, :location_categories

  # Same layout as PDI's FI Inventory Report: site headers, then tank / product / … / ending (14) / extended (18).
  def report(*lines)
    file = Tempfile.new(['fi_inventory', '.csv'])
    CSV.open(file.path, 'w') do |csv|
      csv << ['Tank', 'Product ID']
      lines.each do |line|
        csv << (line.is_a?(String) ? [line] : tank_row(*line))
      end
    end
    file
  end

  def tank_row(tank, product, ending, extended)
    row = Array.new(19)
    row[0] = tank
    row[1] = product
    row[14] = ending
    row[18] = extended
    row
  end

  setup do
    @main = locations(:warehouse).tap { |l| l.update!(pdi_site_code: '0002') }
    @cardlock = locations(:terminal).tap { |l| l.update!(pdi_site_code: '0022') }
    @gas = Product.create!(id: '101', name: '87 Regular', category: 'GASOLINE')
    @def = Product.create!(id: '901', name: 'DEF 32.5%', category: 'DEF-Fuel')
  end

  test 'sums tanks per product and site and sets average cost' do
    file = report('Site 0002 - FPS-Main', ['1.0', '101', '1000', '3000'], ['5.0', '101', '500', '1600'],
                  ['901.0', '901', '20000', '18000'], 'Site Total',
                  'Site 0022 - Cardlock', ['1.0', '101', '250', '800'], 'Report Totals')
    result = PdiInventoryImportService.new(file).import

    assert_equal 2, result[:updated]
    assert_equal 1500, LocationProduct.find_by(location: @main, product: @gas).quantity
    assert_equal 250, LocationProduct.find_by(location: @cardlock, product: @gas).quantity
    assert_equal 1750, @gas.reload.current_stock
    assert_in_delta 5400.0 / 1750, @gas.cost_per_unit, 0.0001
    assert_equal 20_000, @def.reload.current_stock
  end

  test 'logs stock changes per site and reports unknown products and sites' do
    LocationProduct.create!(location: @main, product: @gas, quantity: 1200)
    file = report('Site 0002 - FPS-Main', ['1.0', '101', '1000', '3000'], ['2.0', 'NOPE', '5', '10'],
                  'Site 0050 - Transport Bulk Plant', ['901.0', '901', '197', '195'])
    result = PdiInventoryImportService.new(file).import

    tx = InventoryTransaction.find_by!(product: @gas)
    assert_equal ['out', 200, @main.id], [tx.direction, tx.quantity, tx.location_id]
    assert_equal ['NOPE'], result[:unmatched_products]
    assert_equal ['0050 Transport Bulk Plant'], result[:unmatched_sites]
    assert_equal 197, @def.reload.current_stock # no mapped site: stock falls back to the report total
  end

  test 'warehouse sync ignores the FI report' do
    files = ['REPORT_ FI INVENTORY REPORT.XLS']
    assert_nil(PdiProductSyncJob::FILE_PATTERNS.lazy.filter_map { |p| files.find { |f| f.match?(p) } }.first)
    assert(PdiFuelInventorySyncJob::FILE_PATTERNS.any? { |p| files.first.match?(p) })
    assert(PdiProductSyncJob::FILE_PATTERNS.any? { |p| 'LoadNTrucks-CurrentInventory.xls'.match?(p) })
  end
end
