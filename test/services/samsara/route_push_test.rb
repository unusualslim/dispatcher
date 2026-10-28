require 'test_helper'
require_relative '../../support/fake_samsara_client'

module Samsara
  ROUTE_TEST_ADDRESSES = [
    { 'id' => 'addr-yard', 'name' => 'Five Points Service - Main Office',
      'formattedAddress' => '10154 US-341, Fort Valley, GA 31030, USA', 'latitude' => 32.5, 'longitude' => -83.8 },
    { 'id' => 'addr-nutrien', 'name' => 'Nutrien Augusta',
      'formattedAddress' => '733 Laney Walker Blvd, Augusta, GA', 'latitude' => 33.4605, 'longitude' => -81.9900 },
    { 'id' => 'addr-ta', 'name' => 'TA Spartanburg',
      'formattedAddress' => '1402 E Main St, Duncan, SC 29334, USA', 'latitude' => 34.9, 'longitude' => -82.1 }
  ].freeze

  class RoutePushTest < ActiveSupport::TestCase
    setup do
      LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
      LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
      @yard = Location.create!(company_name: 'Five Points Service,Inc.', address: '10154 US Highway 341',
                               city: 'Fort Valley', state: 'GA', zip: '31030', location_category_id: 1)
      @terminal = Location.create!(company_name: 'Nutrien - Augusta', address: '1460 Columbia Nitrogen Dr',
                                   city: 'Augusta', state: 'GA', zip: '30901', location_category_id: 1,
                                   latitude: 33.4601, longitude: -81.9902)
      @site = Location.create!(company_name: 'TA-Spartanburg', address: 'Travel Center #25', city: 'Duncan',
                               state: 'SC', location_category_id: 2, notes: 'Tank in back')
      @new_site = Location.create!(company_name: 'Brand New Customer', address: '5 Elm St', city: 'Perry',
                                   state: 'GA', zip: '31069', location_category_id: 2)
      @driver = User.create!(email: 'neal@example.com', password: 'password123', role: 'worker',
                             first_name: 'Neal', last_name: 'Harris')
      @product = Product.create!(id: 'DEF1', name: 'Bulk DEF', unit_of_measurement: 'Gallon')
      @dispatch = Dispatch.create!(dispatch_date: Date.new(2026, 10, 30), driver: @driver, notes: 'Release # 9713957',
                                   origin: @terminal.full_address_with_company)
      add_order(@site, 'OD-1', 4500)
      add_order(@site, 'OD-2', 500)
      add_order(@new_site, 'OD-3', 300)
      AppSetting.set('samsara_home_location_id', @yard.id)

      @client = FakeSamsaraClient.new(
        drivers: [{ 'id' => 'drv-9', 'name' => 'Neal Harris' }],
        addresses: ROUTE_TEST_ADDRESSES.map(&:dup)
      )
    end

    def add_order(location, number, qty)
      order = CustomerOrder.create!(location: location, order_status: 'dispatched', external_order_no: number)
      order.customer_order_products.create!(product: @product, quantity: qty, price: 1)
      @dispatch.customer_orders << order
    end

    test 'builds home → terminal → customer stops → home and remembers the links' do
      AppSetting.set('samsara_route_start_time', '07:30')
      @site.update!(samsara_address_id: 'addr-ta') # linked before; "TA-Spartanburg" has no street or GPS to match

      route_id = RoutePush.new(@dispatch, client: @client).call!

      assert_equal 'route-1', route_id
      address_post, route_post = @client.posts
      assert_equal '/addresses', address_post.first
      assert_equal 'Brand New Customer', address_post.last[:name]
      assert_equal '5 Elm St, Perry, GA 31069', address_post.last[:formattedAddress]

      body = route_post.last
      assert_equal '/fleet/routes', route_post.first
      assert_equal "Neal - Dispatch #{@dispatch.id}", body[:name]
      assert_equal 'drv-9', body[:driverId]
      assert body[:recomputeScheduledTimes]
      assert_equal %w[addr-yard addr-nutrien addr-ta addr-new-1 addr-yard], body[:stops].pluck(:addressId)

      start = Time.zone.local(2026, 10, 30, 7, 30)
      assert_equal start.iso8601, body[:stops].first[:scheduledDepartureTime]
      assert_nil body[:stops].first[:scheduledArrivalTime]
      assert(body[:stops][1..3].all? { |s| s[:scheduledArrivalTime].present? })
      assert_nil body[:stops].last[:scheduledArrivalTime]

      assert_includes body[:stops][1][:notes], '5,300 Gallon Bulk DEF'
      assert_includes body[:stops][1][:notes], 'Release # 9713957'
      ta_notes = body[:stops][2][:notes]
      assert_includes ta_notes, 'Order OD-1'
      assert_includes ta_notes, 'Order OD-2'
      assert_includes ta_notes, '500 Gallon Bulk DEF'
      assert_includes ta_notes, 'Tank in back'

      assert_equal 'drv-9', @driver.reload.samsara_driver_id
      assert_equal 'addr-yard', @yard.reload.samsara_address_id # street address match
      assert_equal 'addr-nutrien', @terminal.reload.samsara_address_id # GPS match
      assert_equal 'addr-new-1', @new_site.reload.samsara_address_id
      assert_equal 'route-1', @dispatch.reload.samsara_route_id
      assert_not_nil @dispatch.samsara_sent_at
    end

    test 'skips the terminal stop when the driver starts from it' do
      @driver.update!(home_location: @terminal)
      @site.update!(samsara_address_id: 'addr-ta')

      body = RoutePush.new(@dispatch, client: @client).build

      assert_equal %w[addr-nutrien addr-ta addr-new-1 addr-nutrien], body[:stops].pluck(:addressId)
      assert_includes body[:stops].first[:notes], 'Load:'
    end

    test 'resending replaces the stops of a route not yet started, refuses a started one' do
      @site.update!(samsara_address_id: 'addr-ta')
      @dispatch.update!(samsara_route_id: 'route-7')
      @client.routes['route-7'] = { 'id' => 'route-7' }

      RoutePush.new(@dispatch, client: @client).call!
      assert_equal '/fleet/routes/route-7', @client.patches.sole.first
      assert_not_includes @client.posts.map(&:first), '/fleet/routes'

      @client.routes['route-7'] = { 'id' => 'route-7', 'actualRouteStartTime' => '2026-10-30T12:00:00Z' }
      error = assert_raises(Error) { RoutePush.new(@dispatch, client: @client).call! }
      assert_match(/already started/, error.message)
    end

    test 'a route deleted in Samsara is created again' do
      @site.update!(samsara_address_id: 'addr-ta')
      @dispatch.update!(samsara_route_id: 'gone')

      RoutePush.new(@dispatch, client: @client).call!

      assert_includes @client.posts.map(&:first), '/fleet/routes'
    end

    test 'explains what is missing' do
      @client.instance_variable_set(:@drivers, [])
      error = assert_raises(Error) { RoutePush.new(@dispatch, client: @client).build }
      assert_match(/Neal Harris isn't linked/, error.message)

      @dispatch.update!(driver: nil)
      error = assert_raises(Error) { RoutePush.new(@dispatch, client: @client).build }
      assert_match(/Assign a driver/, error.message)
    end
  end
end
