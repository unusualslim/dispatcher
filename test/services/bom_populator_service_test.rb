require "test_helper"

class BomPopulatorServiceTest < ActiveSupport::TestCase
  fixtures :products, :product_components, :production_orders, :production_order_batches, :vendors

  setup do
    @product    = products(:def_finished)
    @concentrate = products(:def_concentrate)
    @urea        = products(:urea)
    @order = production_orders(:def_batch_order)
    # Clear any pre-existing components from fixtures
    @order.production_order_components.delete_all
  end

  test "populates components from BOM with correct quantities" do
    result = BomPopulatorService.new(@order).call

    assert result, "BomPopulatorService should return true on success"
    assert_equal 2, @order.production_order_components.count

    concentrate_comp = @order.production_order_components.find_by(product_id: @concentrate.id)
    urea_comp        = @order.production_order_components.find_by(product_id: @urea.id)

    assert_not_nil concentrate_comp, "Should create a component for DEF concentrate"
    assert_not_nil urea_comp, "Should create a component for Urea"

    # 0.325 qty_per_unit * 100 qty_to_make = 32.5
    assert_in_delta 32.5, concentrate_comp.quantity, 0.001,
      "Concentrate quantity should be 0.325 * 100 = 32.5"

    # 2.0 qty_per_unit * 100 qty_to_make = 200.0
    assert_in_delta 200.0, urea_comp.quantity, 0.001,
      "Urea quantity should be 2.0 * 100 = 200.0"
  end

  test "updates existing component quantities when called again after qty_to_make changes" do
    BomPopulatorService.new(@order).call

    # Simulate editing the order to make more
    @order.update!(qty_to_make: 200.0)
    BomPopulatorService.new(@order).call

    concentrate_comp = @order.production_order_components.find_by(product_id: @concentrate.id)

    # 0.325 * 200 = 65.0
    assert_in_delta 65.0, concentrate_comp.quantity, 0.001,
      "Concentrate quantity should update to 0.325 * 200 = 65.0 after qty_to_make change"

    # Should still be 2 components, not 4
    assert_equal 2, @order.production_order_components.count,
      "Should not duplicate components on re-run"
  end

  test "returns false and creates nothing when product has no BOM" do
    empty_product = Product.create!(name: "No BOM Product")
    @order.update!(product: empty_product)

    result = BomPopulatorService.new(@order).call

    assert_equal false, result
    assert_equal 0, @order.production_order_components.count
  end

  test "returns false when production order has no product" do
    @order.update_column(:product_id, nil)
    result = BomPopulatorService.new(@order).call
    assert_equal false, result
  end
end
