require "test_helper"

class MrpEngineTest < ActiveSupport::TestCase
  fixtures :products, :product_components, :vendors, :purchase_orders

  setup do
    # Wipe any lingering customer order data from previous tests
    CustomerOrderProduct.delete_all
    CustomerOrder.delete_all

    @concentrate = products(:def_concentrate)
    @urea        = products(:urea)
    @def_product = products(:def_finished)
    @vendor      = vendors(:chem_supply)  # lead_time_days: 7

    location_cat    = LocationCategory.create!(name: "Test #{SecureRandom.hex(4)}")
    location        = Location.create!(city: "Test City", company_name: "Test Co #{SecureRandom.hex(4)}",
                                        location_category: location_cat)
    @customer_order = CustomerOrder.create!(
      location:               location,
      order_status:           "New",
      required_delivery_date: Date.today + 10
    )
    @customer_order.customer_order_products.delete_all

    CustomerOrderProduct.create!(
      customer_order: @customer_order,
      product:        @def_product,
      quantity:       50,
      price:          0
    )
  end

  test "calculates component requirements from open customer orders" do
    requirements    = MrpEngine.new(horizon_days: 30).run
    concentrate_req = requirements.find { |r| r.product.id == @concentrate.id }
    urea_req        = requirements.find { |r| r.product.id == @urea.id }

    assert_not_nil concentrate_req, "Should have requirement for DEF concentrate"
    assert_not_nil urea_req,        "Should have requirement for Urea"

    # 50 units * 0.325 qty_per_unit = 16.25
    assert_in_delta 16.25,  concentrate_req.total_needed, 0.001,
      "Concentrate: 50 * 0.325 = 16.25"

    # 50 units * 2.0 qty_per_unit = 100.0
    assert_in_delta 100.0, urea_req.total_needed, 0.001,
      "Urea: 50 * 2.0 = 100.0"
  end

  test "calculates shortfall correctly against available stock" do
    # urea: current_stock=20, safety_stock=25 → available = max(20-25, 0) = 0
    # needed=100, shortfall=100
    requirements = MrpEngine.new(horizon_days: 30).run
    urea_req     = requirements.find { |r| r.product.id == @urea.id }

    assert_in_delta 0,     urea_req.available_stock, 0.001,
      "Available stock for urea should be 0 (current 20 minus safety 25, floored at 0)"
    assert_in_delta 100.0, urea_req.shortfall, 0.001,
      "Urea shortfall should be 100.0"
  end

  test "order_by_date uses lead time days correctly" do
    PurchaseOrder.create!(
      vendor: @vendor, product: @concentrate,
      quantity: 100, status: 'draft', trigger_type: 'manual'
    )

    requirements    = MrpEngine.new(horizon_days: 30).run
    concentrate_req = requirements.find { |r| r.product.id == @concentrate.id }
    expected_date   = Date.today + @vendor.lead_time_days.days

    assert_equal expected_date, concentrate_req.order_by_date,
      "order_by_date should be today + lead_time_days (#{@vendor.lead_time_days})"
  end

  test "skips orders outside the horizon" do
    @customer_order.update!(required_delivery_date: Date.today + 60)

    requirements = MrpEngine.new(horizon_days: 30).run
    assert_empty requirements, "Should not include orders outside 30-day horizon"
  end

  test "does not require non-raw-material products" do
    requirements = MrpEngine.new(horizon_days: 30).run
    finished_req = requirements.find { |r| r.product.id == @def_product.id }
    assert_nil finished_req, "Finished goods should not appear as MRP requirements"
  end
end
