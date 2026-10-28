require 'test_helper'

# The printable dispatch order: one landscape sheet per order with two identical halves to cut apart.
class DispatchPrintTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @terminal = Location.create!(company_name: 'Albany Terminal', address: '1 Rack Rd', city: 'Albany', state: 'GA',
                                 zip: '31701', location_category_id: 1, notes: 'Gate code 1234')
    @driver = User.create!(email: 'driver-print@example.com', password: 'password123', role: 'worker',
                           first_name: 'Dana', last_name: 'Driver')
    @dispatch = Dispatch.create!(dispatch_date: Date.current, status: 'Sent to Driver', driver: @driver,
                                 origin: @terminal.full_address_with_company)
    site = Location.create!(company_name: 'Cordele Shop', address: '9 Main St', city: 'Cordele', state: 'GA',
                            location_category_id: 2)
    product = Product.create!(id: 'PRINT1', name: 'Clear Diesel', unit_of_measurement: 'Gallon')
    @order = CustomerOrder.create!(location: site, order_status: 'dispatched', external_order_no: 'OD-1001',
                                   notes: 'Call ahead')
    @order.customer_order_products.create!(product: product, quantity: 7500, price: 3.4567)
    @dispatch.customer_orders << @order
  end

  test 'prints each order twice on one sheet with origin and order details' do
    sign_in User.create!(email: 'admin-print@example.com', password: 'password123', role: 'admin')

    get print_dispatch_path(@dispatch)

    assert_response :success
    assert_select 'body.hide-prices' # prices are hidden until unticked
    assert_select '#hide-prices[checked]'
    assert_select '.sheet', 1
    assert_select '.sheet .copy', 2
    assert_select '.copy-label', text: 'Driver Copy'
    assert_select '.copy-label', text: 'Dispatch Copy'
    assert_select '.copy', text: /Albany Terminal.*1 Rack Rd.*Gate code 1234/m, count: 2
    assert_select '.copy', text: /OD-1001.*Dana Driver.*Cordele Shop/m, count: 2
    assert_select 'td', text: 'PRINT1 – Clear Diesel', count: 2
    assert_select 'td', text: '$3.4567', count: 2
    assert_select 'td', text: '$25,925.25', minimum: 2
    assert_select '.notes', text: /Call ahead/, count: 2
  end

  test 'drivers can print only their own dispatches' do
    sign_in @driver
    get print_dispatch_path(@dispatch)
    assert_response :success

    sign_in User.create!(email: 'other-driver@example.com', password: 'password123', role: 'worker')
    get print_dispatch_path(@dispatch)
    assert_redirected_to dispatches_path
  end
end
