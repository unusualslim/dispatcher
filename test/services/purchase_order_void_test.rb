require 'test_helper'

class PurchaseOrderVoidTest < ActiveSupport::TestCase
  fixtures :products, :vendors, :users, :locations, :location_categories

  setup do
    @admin = users(:admin_user)
    @location = locations(:warehouse)
    @product = products(:urea)
    @po = PurchaseOrder.create!(vendor: vendors(:chem_supply), location: @location, status: 'received',
                                line_items_attributes: [{ product_id: @product.id, quantity: 40, unit_cost: 1.2 }])
  end

  def stock
    LocationProduct.find_by(location: @location, product: @product)&.quantity.to_d
  end

  test 'voiding reverses what the PO posted to inventory' do
    @po.post_to_inventory!(@admin)
    assert_equal 40, stock

    PurchaseOrderVoid.new(@po, @admin, 'Wrong vendor').call!

    assert_equal 0, stock
    assert_equal 'voided', @po.reload.status
    assert_equal ['Wrong vendor', @admin], [@po.void_reason, @po.voided_by]
    assert_equal %w[in out], @po.inventory_transactions.order(:id).pluck(:direction)
  end

  test 'an unposted PO voids without touching inventory' do
    PurchaseOrderVoid.new(@po, @admin, 'Not needed').call!

    assert_equal 0, stock
    assert_empty @po.inventory_transactions
  end

  test 'voided POs are read-only and out of active purchasing' do
    PurchaseOrderVoid.new(@po, @admin, 'Duplicate').call!
    @po.reload

    assert_raises(ActiveRecord::ReadOnlyRecord) { @po.update!(notes: 'changed') }
    assert_not_includes PurchaseOrder.active, @po
    assert_raises(ArgumentError) { PurchaseOrderVoid.new(@po, @admin, 'again').call! }
  end

  test 'a reason is required' do
    assert_raises(ArgumentError) { PurchaseOrderVoid.new(@po, @admin, '').call! }
    assert_not @po.reload.voided?
  end
end
