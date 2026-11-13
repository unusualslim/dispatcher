require 'test_helper'

class InventoryReplayTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories

  setup do
    @location = locations(:warehouse)
    @product = products(:def_finished)
    @product.update!(cost_per_unit: 5)
    LocationProduct.where(product: @product).delete_all
    # Sept 30 on-hand from PDI's report, then opening balances on Oct 1.
    InventoryPosting.post!(product: @product, location: @location, quantity: 100, movement_type: 'pdi_sync',
                           occurred_on: Date.new(2026, 9, 30))
    InventoryRevaluation.opening!(as_of: Date.new(2026, 10, 1))
  end

  def on_hand
    LocationProduct.find_by!(location: @location, product: @product).quantity.to_f
  end

  def shipped_order(number, invoice_date, qty)
    order = CustomerOrder.create!(external_order_no: number, order_status: 'billed', location: locations(:terminal),
                                  invoice_date: invoice_date)
    order.customer_order_products.create!(product_id: @product.id, product_name: @product.id, quantity: qty,
                                          warehouse: '2', location: @location)
    order
  end

  test 'posts receipts and shipped orders in the period, oldest first, once' do
    po = PurchaseOrder.create!(vendor: Vendor.create!(id: 'RPL-V', name: 'Replay Vendor'), location: @location,
                               status: 'received', received_at: Time.zone.local(2026, 10, 10, 9), posted_at: 1.day.ago)
    po.line_items.create!(product: @product, quantity: 50, unit_cost: 6)
    shipped_order('OD-R1', Date.new(2026, 10, 12), 30)
    shipped_order('OD-R2', Date.new(2026, 11, 2), 10) # after the period

    replay = InventoryReplay.new(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31)).run!

    assert_equal({ receipt: 1, production: 0, sale: 1 }, replay.counts)
    assert_equal 120.0, on_hand
    receipt = InventoryTransaction.find_by!(movement_type: 'receipt')
    assert_equal [Date.new(2026, 10, 10), 300.0], [receipt.occurred_on, receipt.total_cost.to_f]
    # (100 × 5 + 300) / 150 = 5.3333 a unit when the sale went out
    assert_in_delta 160.0, InventoryTransaction.find_by!(movement_type: 'sale').total_cost.to_f, 0.01

    again = InventoryReplay.new(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31)).run!
    assert_equal({ receipt: 0, production: 0, sale: 0 }, again.counts)
    assert_equal 120.0, on_hand
  end

  test 'completed production posts on its completion date' do
    order = ProductionOrder.create!(product: @product, location: @location, total_qty_produced: 20)
    order.update_columns(status: 'completed', date_completed: Date.new(2026, 10, 15)) # rubocop:disable Rails/SkipsModelValidations
    InventoryReplay.new(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31)).run!

    output = InventoryTransaction.find_by!(transactable: order, movement_type: 'production_output')
    assert_equal [20.0, Date.new(2026, 10, 15)], [output.quantity.to_f, output.occurred_on]
  end

  test 'finished goods flagged raw material still come in from production' do
    @product.update!(is_raw_material: true) # packaged DEF cases carried the flag in production data
    order = ProductionOrder.create!(product: @product, location: @location, total_qty_produced: 20)
    order.update_columns(status: 'completed', date_completed: Date.new(2026, 10, 15)) # rubocop:disable Rails/SkipsModelValidations
    InventoryReplay.new(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31)).run!

    assert InventoryTransaction.exists?(transactable: order, movement_type: 'production_output')
    assert_equal 120.0, on_hand
  end

  test "won't replay before the opening balances" do
    assert_raises(ArgumentError) { InventoryReplay.new(from: Date.new(2026, 9, 1)).run! }
  end

  test 'reset deletes costed movements, zeroes stock and clears the start date' do
    shipped_order('OD-R3', Date.new(2026, 10, 12), 30)
    InventoryReplay.new(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31)).run!

    removed = InventoryReset.reset!

    assert_equal 3, removed[:movements]
    assert_nil InventoryRevaluation.start_date
    stock = LocationProduct.find_by!(location: @location, product: @product)
    assert_equal [0.0, 0.0], [on_hand, stock.inventory_value.to_f]
    assert_not InventoryTransaction.costed.exists?
    assert_equal 1, CustomerOrder.where(external_order_no: 'OD-R3').count
  end

  test 'completed production with no warehouse is skipped and listed, not posted to the main warehouse' do
    placed = ProductionOrder.create!(number: 'PO-PLACED', product: @product, item: @product.name, status: 'completed',
                                     qty_to_make: 10, total_qty_produced: 10, location: @location,
                                     date_completed: Date.new(2026, 10, 15))
    unplaced = ProductionOrder.create!(number: 'PO-NOWH', product: @product, item: @product.name, status: 'created',
                                       qty_to_make: 5)
    # As PDI's repack import leaves them: completed, no warehouse, nothing posted.
    unplaced.update_columns(status: 'completed', total_qty_produced: 5, date_completed: Date.new(2026, 10, 16)) # rubocop:disable Rails/SkipsModelValidations

    replay = InventoryReplay.new(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31)).run!

    assert_equal 0, replay.counts[:production] # the placed order posted when it was completed
    assert ProductionOrderInventory.posted?(placed)
    assert_not ProductionOrderInventory.posted?(unplaced)
    assert_equal ['PO-NOWH'], replay.skipped_no_warehouse
    assert_match(/1 production order\(s\) skipped, no warehouse.*PO-NOWH/, replay.summary)
  end
end
