require 'test_helper'

class ProductCostLineTest < ActiveSupport::TestCase
  fixtures :products, :product_components

  setup do
    @product = products(:def_finished)
    @consumables = ReportingGroup.create!(name: 'Consumables', item_type: 'non_inventory')
    @labor = ReportingGroup.create!(name: 'Labor', item_type: 'non_inventory', labor: true)
    @overhead = ReportingGroup.create!(name: 'Overhead', item_type: 'non_inventory')
  end

  def line(attrs)
    @product.product_cost_lines.create!({ quantity: 1, per_quantity: 1 }.merge(attrs))
  end

  test 'cost per unit is qty × unit cost ÷ per' do
    pallet = line(description: 'Pallet', reporting_group: @consumables, unit_cost: 13.40, per_quantity: 80)
    tape   = line(description: 'Tape', reporting_group: @consumables, quantity: 30, unit_cost: 21.09,
                  per_quantity: 35_984)

    assert_in_delta 0.1675, pallet.cost_per_unit, 0.00001
    assert_in_delta 0.01758, tape.cost_per_unit, 0.00001
  end

  test 'line labor is priced from the labor rate setting' do
    labor = line(description: 'Variable labor', reporting_group: @labor, per_quantity: 134)

    assert_in_delta 25.0 / 134, labor.cost_per_unit, 0.00001
    assert_in_delta 1.0 / 134, labor.hours_per_unit, 0.000001

    AppSetting.set('labor_rate', '30')
    assert_in_delta 30.0 / 134, labor.reload.cost_per_unit, 0.00001
  end

  test 'non-labor lines need a unit cost' do
    assert_not @product.product_cost_lines.build(description: 'Film', reporting_group: @consumables).valid?
    assert @product.product_cost_lines.build(description: 'Labor', reporting_group: @labor).valid?
  end

  test 'BOM standard cost is materials plus non-inventory costs' do
    products(:def_concentrate).update!(standard_cost: 2.50)
    products(:urea).update!(standard_cost: 1.20)
    material = @product.material_standard_cost # 0.325 concentrate + 2.0 urea
    assert_in_delta (0.325 * 2.50) + (2.0 * 1.20), material, 0.00001

    line(description: 'Pallet', reporting_group: @consumables, unit_cost: 13.40, per_quantity: 80)
    line(description: 'Fixed L&OH', reporting_group: @overhead, quantity: 2.5, unit_cost: 0.0757)

    assert_in_delta 0.1675 + 0.18925, @product.non_inventory_standard_cost, 0.00001
    assert_in_delta material + 0.1675 + 0.18925, @product.bom_standard_cost, 0.00001
  end
end
