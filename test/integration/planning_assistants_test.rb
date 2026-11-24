require 'test_helper'

# Purchasing → Min/Max and Suggested POs, Production → Suggested Production: suggestions a person applies.
class PlanningAssistantsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    ReportingGroup.find_or_create_by!(name: 'PA Packaged') { |g| g.item_type = 'warehouse' }
    @main = Location.create!(company_name: 'PA Main', location_category_id: 1, pdi_site_code: '9302')
    @vendor = Vendor.create!(id: 'V-PA', name: 'PA Supply', lead_time_days: 10)
    @raw = Product.create!(id: 'PA-RAW', name: 'Urea', is_raw_material: true, standard_cost: 2, cost_per_unit: 2)
    @raw.product_vendors.create!(vendor: @vendor, priority: 1)
    @fg = Product.create!(id: 'PA-FG', name: 'DEF 2.5 gal', category: 'PA Packaged', standard_cost: 10)
    ProductComponent.create!(product: @fg, component_product: @raw, quantity_per_unit: 2)
    LocationProduct.create!(product: @raw, location: @main, quantity: 100)
    LocationProduct.create!(product: @fg, location: @main, quantity: 5)
    @yard = Location.create!(company_name: 'PA Yard', location_category_id: 2)
    @customer = Customer.create!(name: 'PA Customer', preferred_contact_method: 'no preference')
    @admin = User.create!(email: 'pa-admin@example.com', password: 'password123', role: 'admin')
  end

  def sale(product, qty, status:, on:, delivery: nil)
    order = CustomerOrder.create!(customer: @customer, location: @yard, order_status: status, order_date: on,
                                  required_delivery_date: delivery)
    order.customer_order_products.create!(product_id: product.id, product_name: product.id, quantity: qty,
                                          location: @main)
  end

  test 'min/max is worked out from 12 months of usage and the turns target, and applied when ticked' do
    sale(@raw, 3650, status: 'billed', on: Date.current - 30) # 10 a day
    row = MinMaxPlanner.new.rows.find { |r| r.product == @raw }

    # 10/day, 10 lead days: safety 50, min 150; order = 2 x (3650/12 - 50) = 508.3 → max 659 (A: 12 turns).
    assert_equal ['A', 10, 50, 150, 659], [row.abc, row.lead_days, row.safety, row.min_qty, row.max_qty]

    sign_in @admin
    get min_max_path
    assert_response :success
    assert_select 'td a', text: 'PA-RAW'
    post apply_min_max_path, params: { product_ids: ['PA-RAW'] }
    assert_equal [50, 150, 659], [@raw.reload.safety_stock, @raw.reorder_point, @raw.max_stock].map(&:to_i)
  end

  test 'suggested POs list items at or below min by vendor and create draft POs only when ticked' do
    @raw.update!(reorder_point: 150, max_stock: 400)
    sign_in @admin
    get suggested_purchases_path
    assert_response :success
    assert_select '.card-header', text: /PA Supply/
    assert_select 'td', text: /At or below min/
    assert_not PurchaseOrder.exists?(vendor_id: 'V-PA')

    post suggested_purchases_path, params: { lines: { '0' => { pick: '1', product_id: 'PA-RAW', location_id: @main.id,
                                                               vendor_id: 'V-PA', quantity: '300', unit_cost: '2' } } }
    po = PurchaseOrder.find_by!(vendor_id: 'V-PA')
    assert_equal ['draft', @main.id], [po.status, po.location_id]
    assert_equal([['PA-RAW', 300]], po.line_items.map { |l| [l.product_id, l.quantity.to_i] })
  end

  test 'suggested production lists the runs open orders need and creates production orders when ticked' do
    sale(@fg, 25, status: 'open_order', on: Date.current, delivery: Date.current + 5)
    run = SuggestedProduction.new.runs.find { |r| r.product == @fg }
    assert_equal [20, @main], [run.quantity, run.location]

    sign_in @admin
    get suggested_productions_path
    assert_response :success
    assert_select 'td a', text: 'PA-FG'

    post suggested_productions_path, params: { runs: { '0' => { pick: '1', product_id: 'PA-FG', location_id: @main.id,
                                                                quantity: '20', start_on: Date.current.iso8601,
                                                                need_date: (Date.current + 5).iso8601 } } }
    order = ProductionOrder.find_by!(product_id: 'PA-FG')
    assert_redirected_to kanban_production_orders_path
    assert_equal ['created', 20, @main, Date.current],
                 [order.status, order.qty_to_make.to_i, order.location, order.production_date]
    assert_equal([['PA-RAW', 40]], order.production_order_components.map { |c| [c.product_id, c.quantity.to_i] })
  end
end
