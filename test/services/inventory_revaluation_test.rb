require 'test_helper'

class InventoryRevaluationTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories, :users

  setup do
    @location = locations(:warehouse)
    @product = products(:urea)
    @product.update!(category: 'Chemicals', standard_cost: 1.00)
    @group = ReportingGroup.find_by!(name: 'Chemicals')
    LocationProduct.where(product: @product).delete_all
  end

  def move(qty, unit_cost = nil, type: qty.positive? ? 'receipt' : 'adjustment')
    InventoryPosting.post!(product: @product.reload, location: @location, quantity: qty, movement_type: type,
                           unit_cost: unit_cost)
  end

  def stock
    LocationProduct.find_by!(location: @location, product: @product)
  end

  def layers(scope = InventoryCostLayer.all)
    scope.where(product_id: @product.id).order(:id).pluck(:remaining_quantity, :unit_cost)
         .map { |qty, cost| [qty.to_i, cost.to_f] }
  end

  test 'opening balances value stock at the basis and start tracking once' do
    LocationProduct.create!(location: @location, product: @product, quantity: 40)
    @product.update!(cost_per_unit: 1.50)
    InventoryRevaluation.opening!(as_of: Date.new(2026, 10, 27))

    assert_equal 60.0, stock.inventory_value.to_f
    assert_equal Date.new(2026, 10, 27), InventoryRevaluation.start_date
    assert_equal 'opening', InventoryTransaction.where(product: @product).last.movement_type
    assert_raises(ArgumentError) { InventoryRevaluation.opening! }
  end

  test 'switching to standard revalues stock; a new standard revalues again' do
    AppSetting.set(InventoryRevaluation::START_DATE_KEY, '2026-10-01')
    move(10, 2.00)
    @group.update!(costing_method: 'standard')
    assert_equal 10.0, stock.inventory_value.to_f

    @product.reload.update!(standard_cost: 1.75)
    assert_equal 17.5, stock.inventory_value.to_f
    revaluations = InventoryTransaction.where(movement_type: 'revaluation').order(:id)
    assert_equal [-10.0, 7.5], revaluations.pluck(:variance_amount).map(&:to_f)
  end

  test 'switching to FIFO starts one layer at the current average' do
    AppSetting.set(InventoryRevaluation::START_DATE_KEY, '2026-10-01')
    move(10, 1.00)
    move(10, 3.00)
    @group.update!(costing_method: 'fifo')

    assert_equal [[20, 2.0]], layers(InventoryCostLayer.open)
    assert_equal 10.0, move(-5).total_cost.to_f
  end
end
