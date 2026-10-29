require 'test_helper'

# Lanes (standard miles) on a location's Freight tab and Freight Rules → Lanes, and the dispatch freight card.
class FreightLanesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @terminal = Location.create!(company_name: 'Frtl Terminal', location_category_id: 1)
    @site = Location.create!(company_name: 'Frtl Site', location_category_id: 2)
    @order = CustomerOrder.create!(location: @site, order_status: 'open_order', order_date: Date.current)
    sign_in User.create!(email: 'admin-freight-lanes@example.com', password: 'password123', role: 'admin')
  end

  test 'location Freight tab adds lanes; the dispatch shows its freight card' do
    post freight_lanes_path, params: { freight_lane: { origin_location_id: @terminal.id,
                                                       destination_location_id: @site.id, standard_miles: 64 } }
    assert_equal 64.to_d, FreightLane.miles(@terminal, @site)
    get location_path(@site, tab: 'freight')
    assert_response :success
    assert_select 'input[value=?]', '64'
    get freight_rules_path(tab: 'lanes')
    assert_select 'td', text: 'Frtl Terminal'

    dispatch = Dispatch.create!(dispatch_date: Date.current, origin: @terminal.full_address_with_company)
    dispatch.customer_orders << @order
    post dispatch_freight_path(dispatch)
    assert_redirected_to dispatch_path(dispatch, anchor: 'freight')
    get dispatch_path(dispatch)
    assert_select '#freight td', /64/
  end
end
