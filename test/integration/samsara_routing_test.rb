require 'test_helper'
require 'minitest/mock'
require_relative '../support/fake_samsara_client'

# Send to Samsara on a dispatch, and Admin → Samsara.
class SamsaraRoutingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @admin = User.create!(email: 'admin-samsara@example.com', password: 'password123', role: 'admin')
    @driver = User.create!(email: 'driver-samsara@example.com', password: 'password123', role: 'worker',
                           first_name: 'Neal', last_name: 'Harris', samsara_driver_id: 'drv-9')
    @yard = Location.create!(company_name: 'Main Office', address: '1 Yard Rd', city: 'Fort Valley',
                             location_category_id: 1, samsara_address_id: 'addr-yard')
    site = Location.create!(company_name: 'Cordele Shop', address: '9 Main St', city: 'Cordele',
                            location_category_id: 2, samsara_address_id: 'addr-site')
    @dispatch = Dispatch.create!(dispatch_date: Date.current, driver: @driver, origin: @yard.full_address_with_company)
    @dispatch.customer_orders << CustomerOrder.create!(location: site, order_status: 'dispatched')
  end

  test 'Send to Samsara creates the route and the button turns into Update' do
    sign_in @admin
    get dispatch_path(@dispatch)
    assert_select 'button', text: /Send to Samsara/

    client = FakeSamsaraClient.new(drivers: [], addresses: [])
    Samsara::Client.stub(:new, client) { post send_to_samsara_dispatch_path(@dispatch) }

    assert_redirected_to dispatch_path(@dispatch)
    assert_equal 'Route sent to Samsara for Neal Harris.', flash[:notice]
    assert_equal %w[addr-yard addr-site addr-yard], client.posts.sole.last[:stops].pluck(:addressId)
    follow_redirect!
    assert_select 'button', text: /Update in Samsara/
  end

  test 'problems come back as an alert' do
    sign_in @admin
    Samsara::Client.stub(:new, -> { raise Samsara::NotConfigured, 'Samsara is not set up.' }) do
      post send_to_samsara_dispatch_path(@dispatch)
    end
    assert_equal 'Samsara is not set up.', flash[:alert]
  end

  test 'staff without dispatch edit cannot send' do
    sign_in User.create!(email: 'viewer-samsara@example.com', password: 'password123', role: 'staff',
                         permissions: { 'dispatch' => 'view' })
    post send_to_samsara_dispatch_path(@dispatch)
    assert_nil @dispatch.reload.samsara_route_id
  end

  test 'admin page saves start time, default home base and driver links even when Samsara is unreachable' do
    sign_in @admin
    Samsara::Client.stub(:new, -> { raise Samsara::NotConfigured, 'Samsara is not set up.' }) do
      get edit_samsara_settings_path
    end
    assert_response :success
    assert_select '.alert-warning', /not set up/

    patch samsara_settings_path, params: {
      samsara_route_start_time: '06:45', samsara_home_location_id: @yard.id,
      drivers: { @driver.id => { samsara_driver_id: 'drv-10', home_location_id: @yard.id } }
    }
    assert_redirected_to edit_samsara_settings_path
    assert_equal '06:45', Samsara::RoutePush.start_time
    assert_equal @yard, Samsara::RoutePush.default_home
    assert_equal ['drv-10', @yard.id], [@driver.reload.samsara_driver_id, @driver.home_location_id]

    delete unlink_location_samsara_settings_path(location_id: @yard.id)
    assert_nil @yard.reload.samsara_address_id
  end

  test 'Samsara settings are admin-only' do
    sign_in User.create!(email: 'staff-samsara@example.com', password: 'password123', role: 'staff',
                         permissions: { 'dispatch' => 'approve' })
    get edit_samsara_settings_path
    assert_response :redirect
  end
end
