require 'test_helper'

class RepackBatchImportServiceTest < ActiveSupport::TestCase
  fixtures :locations, :location_categories

  setup do
    @main = locations(:warehouse).tap { |l| l.update!(company_name: 'Five Points - Main', pdi_site_code: '0002') }
    @south = locations(:terminal).tap { |l| l.update!(company_name: 'Five Points South', pdi_site_code: '0110') }
    @product = Product.create!(id: 'DEF25', name: 'DEF 2.5 gal case')
    @component = Product.create!(id: 'DEFBULK', name: 'DEF bulk', cost_per_unit: 2)
  end

  # One batch row in PDI's repack export layout (only the columns the importer reads, by index).
  def export(batch_key, warehouse_id, warehouse_name)
    row = Array.new(40)
    { 0 => batch_key, 1 => 'Repack', 2 => '2026-10-27', 3 => 'Posted', 8 => warehouse_id, 9 => warehouse_name,
      13 => @product.id, 16 => '100', 28 => "#{batch_key}-C", 29 => @component.id, 36 => '50' }
      .each { |index, value| row[index] = value }
    Tempfile.new(['repack', '.csv']).tap { |file| CSV.open(file.path, 'w') { |csv| csv << row } }
  end

  test 'finds the location by PDI warehouse ID even when the PDI name matches no location' do
    result = RepackBatchImportService.call(export('15180', '110', 'FPS-South').path)

    assert_equal 1, result.created
    assert_equal @south, ProductionOrder.find_by!(number: 'PDI-15180').location
  end

  test 'accepts the zero padded site code' do
    RepackBatchImportService.call(export('15181', '0002', 'FPS-Main').path)

    assert_equal @main, ProductionOrder.find_by!(number: 'PDI-15181').location
  end

  test 'falls back to the warehouse name when the ID is blank or unknown' do
    @south.update!(company_name: 'FPS-South')
    RepackBatchImportService.call(export('15182', nil, 'FPS-South').path)

    assert_equal @south, ProductionOrder.find_by!(number: 'PDI-15182').location
  end

  test 'leaves the location empty and flags the batch when nothing matches' do
    result = RepackBatchImportService.call(export('15183', '9999', 'Somewhere').path)

    assert_nil ProductionOrder.find_by!(number: 'PDI-15183').location
    assert_equal 1, result.errors.size
    assert_match(/Batch 15183: warehouse 9999 Somewhere matches no location/, result.errors.first)
  end

  test 'does not flag a matched batch' do
    assert_empty RepackBatchImportService.call(export('15184', '2', 'FPS-Main').path).errors
  end

  test 'preview marks whether the warehouse matched' do
    matched = RepackBatchImportService.new(export('15185', '110', 'FPS-South').path).preview.first
    unmatched = RepackBatchImportService.new(export('15186', '9999', 'Somewhere').path).preview.first

    assert matched.warehouse_matched
    assert_not unmatched.warehouse_matched
  end

  def stock_at(location, product)
    LocationProduct.find_by(location: location, product: product)&.quantity.to_d
  end

  test 'a later import fills the warehouse of an order that had none and moves its inventory' do
    RepackBatchImportService.call(export('15190', '9999', 'Unknown').path)
    order = ProductionOrder.find_by!(number: 'PDI-15190')
    ProductionOrderInventory.post!(order)
    assert_nil order.location
    assert ProductionOrderInventory.posted?(order)

    preview = RepackBatchImportService.new(export('15190', '110', 'FPS-South').path).preview.first
    assert_equal :set_warehouse, preview.action
    assert preview.moves_inventory

    result = RepackBatchImportService.call(export('15190', '110', 'FPS-South').path)

    assert_equal 1, result.warehouse_set
    assert_equal 1, result.reposted
    assert_equal @south, order.reload.location
    assert_equal(-50, stock_at(@south, @component))
    assert_equal 100, stock_at(@south, @product)
    assert_equal 0, stock_at(@main, @product) + stock_at(@main, @component)
  end

  test 'an order that already has a warehouse is never changed by a later import' do
    RepackBatchImportService.call(export('15191', '2', 'FPS-Main').path)
    result = RepackBatchImportService.call(export('15191', '110', 'FPS-South').path)

    assert_equal 0, result.warehouse_set
    assert_equal 1, result.skipped_exists
    assert_equal @main, ProductionOrder.find_by!(number: 'PDI-15191').location
  end

  test 'an existing order stays flagged when its warehouse still matches nothing' do
    RepackBatchImportService.call(export('15192', '9999', 'Unknown').path)
    result = RepackBatchImportService.call(export('15192', '9999', 'Unknown').path)

    assert_equal 0, result.warehouse_set
    assert_match(/Batch 15192: warehouse 9999 Unknown matches no location/, result.errors.first)
  end
end
