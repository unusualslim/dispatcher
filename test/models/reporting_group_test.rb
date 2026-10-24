require 'test_helper'

class ReportingGroupTest < ActiveSupport::TestCase
  fixtures :products, :product_components

  test 'a product with a new PDI category gets a warehouse reporting group' do
    product = products(:def_finished)
    product.update!(category: 'LUBE-PACKAGED')

    group = ReportingGroup.find_by!(name: 'LUBE-PACKAGED')
    assert_equal 'warehouse', group.item_type
    assert_equal group, product.reload.reporting_group

    products(:urea).update!(category: 'LUBE-PACKAGED')
    assert_equal 1, ReportingGroup.where(name: 'LUBE-PACKAGED').count
  end

  test 'PDI groups keep their name and stay on the PDI side' do
    group = ReportingGroup.create!(name: 'DEF', item_type: 'warehouse')

    assert_not group.update(name: 'DEF BULK')
    assert group.reload.update(item_type: 'fuel')
    assert_not group.update(item_type: 'non_inventory')
    assert_not group.reload.update(labor: true)
    assert group.reload.update(post_production_gl: true)
  end

  test 'production GL switch is only for fuel and warehouse categories' do
    assert_not ReportingGroup.new(name: 'Overhead', item_type: 'non_inventory', post_production_gl: true).valid?
  end

  test 'cost lines must use a non-inventory group' do
    warehouse = ReportingGroup.create!(name: 'COMPONENTS', item_type: 'warehouse')
    consumables = ReportingGroup.create!(name: 'Consumables', item_type: 'non_inventory')
    product = products(:def_finished)

    assert_not product.product_cost_lines.build(description: 'Pallet', reporting_group: warehouse, unit_cost: 1).valid?
    assert product.product_cost_lines.build(description: 'Pallet', reporting_group: consumables, unit_cost: 1).valid?
  end
end
