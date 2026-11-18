require 'test_helper'

class BomVersionTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(id: 'BV-DEF', name: 'DEF 2.5 gal')
    @urea = Product.create!(id: 'BV-UREA', name: 'Urea')
    @jug = Product.create!(id: 'BV-JUG', name: 'Jug')
  end

  test 'a new version is saved only when the BOM changes, and production orders keep theirs' do
    assert_nil BomVersion.capture!(@product), 'no BOM, nothing saved'

    ProductComponent.create!(product: @product, component_product: @urea, quantity_per_unit: 2, uom: 'LB')
    v1 = BomVersion.capture!(@product)
    assert_equal 1, v1.number
    assert_equal v1, BomVersion.capture!(@product), 'unchanged BOM keeps the version'

    order = ProductionOrder.create!(product: @product, status: 'created', qty_to_make: 10)
    assert_equal v1, order.bom_version

    ProductComponent.create!(product: @product, component_product: @jug, quantity_per_unit: 1, uom: 'EA')
    @product.product_components.find_by!(component_product: @urea).update!(quantity_per_unit: 2.5)
    second = ProductionOrder.create!(product: @product, status: 'created', qty_to_make: 10)
    v2 = second.bom_version
    assert_equal 2, v2.number
    assert_equal v1, order.reload.bom_version
    assert_equal ['Added BV-JUG (1 EA)', 'Changed BV-UREA: 2 LB → 2.5 LB'], v2.changes_from(v1)
  end
end
