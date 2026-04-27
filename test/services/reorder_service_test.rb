require "test_helper"

class ReorderServiceTest < ActiveSupport::TestCase
  fixtures :products, :vendors, :purchase_orders

  setup do
    @urea    = products(:urea)     # current_stock:20, reorder_point:100, safety_stock:25
    @vendor  = vendors(:chem_supply)
  end

  test "creates a draft PO for products below reorder point" do
    assert_difference "PurchaseOrder.count", 1 do
      ReorderService.run
    end

    po = PurchaseOrder.last
    assert_equal 'draft',    po.status
    assert_equal @urea.id,   po.product_id
  end

  test "calculates order quantity to reach reorder_point + safety_stock" do
    ReorderService.run
    po = PurchaseOrder.order(created_at: :desc).first

    # target = reorder_point(100) + safety_stock(25) = 125
    # qty    = target(125) - current_stock(20) = 105
    assert_equal 105, po.quantity
  end

  test "does not create a duplicate PO if one is already active" do
    PurchaseOrder.create!(
      product:      @urea,
      vendor:       @vendor,
      quantity:     50,
      status:       'draft',
      trigger_type: 'auto_reorder'
    )

    assert_no_difference "PurchaseOrder.count" do
      ReorderService.run
    end
  end

  test "does not create a PO for products above reorder point" do
    @urea.update!(current_stock: 200.0)

    assert_no_difference "PurchaseOrder.count" do
      ReorderService.run
    end
  end

  test "does not create POs for finished goods" do
    @urea.update!(current_stock: 200.0)  # prevent urea from triggering reorder
    finished = products(:def_finished)   # is_raw_material: false
    # Even if stock is 0, finished goods should not trigger auto-reorder
    finished.update!(reorder_point: 100.0)

    assert_no_difference "PurchaseOrder.count" do
      ReorderService.run
    end
  end
end
