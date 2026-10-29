require 'test_helper'

class LocationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'locations-admin@example.com', password: 'password123', role: 'admin')
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @location = Location.create!(company_name: 'Big Warehouse', city: 'Americus', location_category_id: 2)
    60.times do |i|
      product = Product.create!(id: "LOCP#{i.to_s.rjust(2, '0')}", name: "Product #{i.to_s.rjust(2, '0')}")
      @location.location_products.create!(product: product, quantity: i)
    end
    30.times { CustomerOrder.create!(location: @location, order_status: 'open_order') }
  end

  test 'show opens on orders and keeps products in their own paginated tab' do
    get location_url(@location)
    assert_response :success
    assert_select '.nav-tabs .nav-link.active', /Customer Orders\s*30/
    assert_select '.nav-tabs .nav-link', /Products\s*60/
    assert_select 'td', text: 'Product 00', count: 0
    assert_select 'tbody tr', 25
    assert_select ".pagination a[href*='tab=orders'][href*='page=2']"

    get location_url(@location, tab: 'products')
    assert_select 'tbody tr', 50
    assert_select 'td', text: 'Product 00'
    assert_select ".pagination a[href*='tab=products'][href*='page=2']"

    get location_url(@location, tab: 'products', page: 2)
    assert_select 'tbody tr', 10
    assert_select 'td', text: 'Product 59'
  end

  test 'customers tab' do
    @location.customers << Customer.create!(name: 'Akins Oil')
    get location_url(@location, tab: 'customers')
    assert_select '.card-title', /Akins Oil/
  end
end
