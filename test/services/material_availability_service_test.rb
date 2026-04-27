require "test_helper"

class MaterialAvailabilityServiceTest < ActiveSupport::TestCase
  fixtures :products, :product_components, :production_orders, :production_order_batches, :vendors

  setup do
    @order       = production_orders(:def_batch_order)   # qty_to_make: 100
    @concentrate = products(:def_concentrate)             # current_stock: 500, safety: 50 → available: 450
    @urea        = products(:urea)                        # current_stock: 20, safety: 25 → available: 0

    @order.production_order_components.delete_all
    BomPopulatorService.new(@order).call  # sets concentrate=32.5, urea=200.0
  end

  test "returns ok when available stock covers need" do
    # concentrate available=450, needed=32.5 → ok
    results  = MaterialAvailabilityService.new(@order).check
    conc_res = results.find { |r| r.product.id == @concentrate.id }
    assert_equal :ok, conc_res.status
  end

  test "returns short when current_stock is insufficient" do
    # urea available=0 (safety eats it all), current_stock=20, needed=200 → short
    results  = MaterialAvailabilityService.new(@order).check
    urea_res = results.find { |r| r.product.id == @urea.id }
    assert_equal :short, urea_res.status
  end

  test "returns low when current_stock covers need but dips into safety stock" do
    # Set urea current_stock to exactly 210 (needed=200, safety=25)
    # available = 210-25 = 185 < 200, but current_stock 210 >= 200 → :low
    @urea.update!(current_stock: 210.0)
    results  = MaterialAvailabilityService.new(@order).check
    urea_res = results.find { |r| r.product.id == @urea.id }
    assert_equal :low, urea_res.status
  end

  test "all_ok? returns true when every component is sufficiently stocked" do
    # Give urea enough stock to be comfortable
    @urea.update!(current_stock: 500.0)
    assert MaterialAvailabilityService.new(@order).all_ok?
  end

  test "any_short? returns true when at least one component is short" do
    # urea is short by default in fixtures
    assert MaterialAvailabilityService.new(@order).any_short?
  end

  test "available stock cannot go below zero" do
    # current_stock(20) - safety_stock(25) should floor at 0, not -5
    assert_equal 0, @urea.available_stock
  end
end
