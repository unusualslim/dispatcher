require "test_helper"

class ProductionOrderBatchTest < ActiveSupport::TestCase
  fixtures :products, :product_components, :production_orders, :production_order_batches, :vendors

  setup do
    @order       = production_orders(:def_batch_order)  # qty_to_make: 100
    @concentrate = products(:def_concentrate)            # current_stock: 500, is_raw_material: true
    @urea        = products(:urea)                       # current_stock: 20,  is_raw_material: true
    @finished    = products(:def_finished)               # current_stock: 0,   is_raw_material: false
    @user        = User.create!(email: "test@example.com", password: "password123",
                                first_name: "Test", last_name: "User")

    @order.production_order_components.delete_all
    BomPopulatorService.new(@order).call
    # Components after BOM: concentrate=32.5, urea=200.0 for 100 units

    @batch = production_order_batches(:batch_one)  # quantity: 60, qc_status: passed
    @batch.generate_lot_number!
  end

  # ── Proportional deduction ─────────────────────────────────────────────

  test "deducts proportional component stock based on batch quantity" do
    # batch is 60 out of 100 total → 60% ratio
    # concentrate: 32.5 * 0.6 = 19.5 deducted, leaving 500 - 19.5 = 480.5
    concentrate_before = @concentrate.current_stock

    @batch.complete_and_deduct_inventory!(@user)

    @concentrate.reload
    expected_deduction = 32.5 * (60.0 / 100.0)  # 19.5
    assert_in_delta concentrate_before - expected_deduction, @concentrate.current_stock, 0.001,
      "Concentrate should be deducted proportionally (60/100 of 32.5 = 19.5)"
  end

  test "two batches together deduct 100% of materials, not 200%" do
    batch2 = production_order_batches(:batch_two)
    batch2.update!(qc_status: "passed")
    batch2.generate_lot_number!

    concentrate_before = @concentrate.current_stock

    @batch.complete_and_deduct_inventory!(@user)   # 60% = 19.5
    batch2.complete_and_deduct_inventory!(@user)   # 40% = 13.0

    @concentrate.reload
    total_deducted = concentrate_before - @concentrate.current_stock
    assert_in_delta 32.5, total_deducted, 0.01,
      "Two batches (60+40) should deduct exactly 32.5 total, not 200% (65.0)"
  end

  test "adds finished goods to inventory equal to batch quantity" do
    finished_before = @finished.current_stock
    @batch.complete_and_deduct_inventory!(@user)
    @finished.reload
    assert_in_delta finished_before + 60.0, @finished.current_stock, 0.001,
      "Should add batch quantity (60) to finished goods stock"
  end

  test "refuses to complete a batch that has not passed QC" do
    pending_batch = production_order_batches(:batch_two)  # qc_status: pending
    result = pending_batch.complete_and_deduct_inventory!(@user)
    assert_equal false, result, "Should return false for non-passed QC status"
  end

  test "records one inventory transaction per component plus one for finished good" do
    assert_difference "InventoryTransaction.count", 3 do
      # 2 raw material components (concentrate + urea) + 1 finished good = 3 transactions
      @batch.complete_and_deduct_inventory!(@user)
    end
  end

  # ── Lot number generation ───────────────────────────────────────────────

  test "lot number matches expected format FPS-PRODUCT-DATE-SEQ" do
    assert_match(/\AFPS-[A-Z0-9]+-\d{8}-\d{3}\z/, @batch.lot_number)
  end

  test "sequential lot numbers on same day are unique" do
    batch2 = production_order_batches(:batch_two)
    batch2.generate_lot_number!
    refute_equal @batch.lot_number, batch2.lot_number
  end
end
