require 'test_helper'

class MrpTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @plant = Location.create!(company_name: 'Mrp Plant', location_category_id: 1)
    @raw = Product.create!(id: 'MRPI-RAW', name: 'Mrp Urea', is_raw_material: true)
    LocationProduct.create!(product: @raw, location: @plant, quantity: 10)
    order = CustomerOrder.create!(location: Location.create!(company_name: 'Mrp Yard', location_category_id: 2),
                                  order_status: 'open_order', required_delivery_date: Date.current + 9)
    order.customer_order_products.create!(product_id: @raw.id, product_name: @raw.id, quantity: 25, location: @plant)
  end

  test 'purchasing staff see what runs out and when to order, and the product timeline' do
    sign_in User.create!(email: 'buyer-mrp@example.com', password: 'password123', role: 'staff',
                         permissions: { 'purchasing' => 'edit' })

    get mrp_path
    assert_response :success
    assert_select 'td', /Order\s+15\s+by/
    assert_select 'a[href=?]', mrp_product_path(@raw.id, horizon: 60), 'Mrp Urea'

    get mrp_product_path(@raw.id)
    assert_response :success
    assert_select 'td', /Suggested: Order by/

    patch mrp_settings_path, params: { mrp_purchase_lead_days: '12', horizon: 30 }
    assert_redirected_to mrp_path(horizon: 30)
    assert_equal 12, AppSetting.mrp_days('mrp_purchase_lead_days')
  end

  test 'users without purchasing access cannot open MRP' do
    sign_in User.create!(email: 'sales-mrp@example.com', password: 'password123', role: 'staff',
                         permissions: { 'sales' => 'edit' })
    get mrp_path
    assert_response :redirect
  end

  test 'production orders show a materials dot on the list and per component' do
    sign_in User.create!(email: 'prod-mrp@example.com', password: 'password123', role: 'admin')
    order = ProductionOrder.create!(number: 'MRPI-1', status: 'created', production_date: Date.current + 1,
                                    location: @plant)
    order.production_order_components.create!(product: @raw, description: 'Urea', quantity: 5)

    get production_orders_path
    assert_select "span.rounded-circle[title*='In stock']"

    get production_order_path(order)
    assert_select 'td', /In stock: 10 on hand covers this and earlier needs/
  end
end
