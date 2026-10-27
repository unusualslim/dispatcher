require 'test_helper'

class InventoryPostingTest < ActiveSupport::TestCase
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

  test 'weighted average re-averages on receipt and issues at the average' do
    move(100, 2.00)
    move(100, 4.00)
    issue = move(-50)

    assert_equal 150.0, issue.total_cost.to_f
    assert_equal 3.0, issue.unit_cost.to_f
    assert_equal [150, 450], [stock.quantity.to_i, stock.inventory_value.to_i]
    assert_equal [150, 450], [issue.balance_quantity.to_i, issue.balance_value.to_i]
    assert_equal 150, @product.reload.current_stock.to_i
  end

  test 'weighted average takes the whole value when the last of the stock goes' do
    move(3, 1.00)
    move(-1)
    move(-2)

    assert_equal [0, 0], [stock.quantity.to_i, stock.inventory_value.to_f]
  end

  test 'standard books receipts at standard and keeps the difference as variance' do
    @group.update!(costing_method: 'standard')
    receipt = move(100, 1.25)

    assert_equal 100.0, receipt.total_cost.to_f
    assert_equal 25.0, receipt.variance_amount.to_f
    assert_equal 30.0, move(-30).total_cost.to_f
    assert_equal 70.0, stock.inventory_value.to_f
  end

  test 'FIFO issues use up the oldest layers first' do
    @group.update!(costing_method: 'fifo')
    move(10, 1.00)
    move(10, 2.00)
    issue = move(-15)

    assert_equal 20.0, issue.total_cost.to_f
    assert_equal [[5, 2.0]], layers(InventoryCostLayer.open)
    assert_equal 10.0, stock.inventory_value.to_f
  end

  test 'reversing a FIFO issue puts the quantity back in the same layers' do
    @group.update!(costing_method: 'fifo')
    move(10, 1.00)
    move(10, 2.00)
    issue = move(-15)
    reversal = InventoryPosting.reverse!(issue, source: nil, reference: 'X')

    assert_equal [20.0, 'in'], [reversal.total_cost.to_f, reversal.direction]
    assert_equal [[10, 1.0], [10, 2.0]], layers
    assert_equal [20, 30.0], [stock.quantity.to_i, stock.inventory_value.to_f]
  end

  test 'reversing a receipt takes it out at its own cost' do
    move(10, 1.00)
    receipt = move(10, 3.00)
    InventoryPosting.reverse!(receipt, source: nil, reference: 'X')

    assert_equal [10, 10.0], [stock.quantity.to_i, stock.inventory_value.to_f]
  end

  test 'issuing more than on hand goes negative at the current cost' do
    move(5, 2.00)
    move(-8)

    assert_equal [-3, -6.0], [stock.quantity.to_i, stock.inventory_value.to_f]
  end

  test 'movements with no location post at the main warehouse' do
    @location.update!(pdi_site_code: '0002')
    txn = InventoryPosting.post!(product: @product, location: nil, quantity: 4, movement_type: 'adjustment')

    assert_equal @location.id, txn.location_id
  end
end
