require 'test_helper'

# Orders and dispatches carrying hazmat products warn the dispatcher (placards / hazmat-endorsed driver).
class HazmatWarningTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  WASHER = 'UN1993, Flammable liquid, n.o.s. (methanol), 3, PG III'.freeze

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    site = Location.create!(company_name: 'Cordele Shop', address: '9 Main St', city: 'Cordele', state: 'GA',
                            location_category_id: 2)
    @washer = Product.create!(id: 'HZ-WW20', name: '-20 WW Drum', unit_of_measurement: '55GA',
                              hazmat: true, hazmat_description: WASHER)
    @order = CustomerOrder.create!(location: site, order_status: 'dispatched')
    @order.customer_order_products.create!(product: @washer, quantity: 4)
    @order.customer_order_products.create!(product: Product.create!(id: 'HZ-DEF', name: 'DEF Bulk'), quantity: 10)
    @dispatch = Dispatch.create!(dispatch_date: Date.current, status: 'New')
    @dispatch.customer_orders << @order
    sign_in User.create!(email: 'admin-hazmat@example.com', password: 'password123', role: 'admin')
  end

  test 'the order page warns and badges the hazardous line' do
    get customer_order_path(@order)

    assert_response :success
    assert_select '.alert-danger', text: /Hazardous materials on this order.*-20 WW Drum.*#{Regexp.escape(WASHER)}/m
    assert_select '.badge', text: 'Hazmat', count: 1
  end

  test 'the dispatch page, edit form and kanban card warn' do
    get dispatch_path(@dispatch)
    assert_select '.alert-danger', text: /Hazardous materials on this load.*hazmat endorsement.*-20 WW Drum/m
    assert_select 'td', text: /-20 WW Drum\s+Hazmat/

    get edit_dispatch_path(@dispatch)
    assert_select '.alert-danger', text: /Hazardous materials on this load/

    get kanban_dispatches_path
    assert_select '.kanban-card .badge', text: 'Hazmat'
  end

  test 'no warning without hazmat products' do
    @washer.update!(hazmat: false)

    get dispatch_path(@dispatch)
    assert_select '.alert-danger', text: /Hazardous materials/, count: 0
  end
end
