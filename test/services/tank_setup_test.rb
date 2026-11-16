require 'test_helper'
require Rails.root.join('test/support/tank_feed_files').to_s

class TankSetupTest < ActiveSupport::TestCase
  include TankFeedFiles

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @site = Location.create!(company_name: 'TS Site', location_category_id: 2)
    @def = Product.find_by(id: '901') || Product.create!(id: '901', name: 'Bulk DEF')
  end

  def smartank_tank(details = {})
    FeedTank.create!(feed: 'smartank', external_id: "TS-#{SecureRandom.hex(3)}", name: 'JET WRENS DEF',
                     details: { 'capacity' => '2,198', 'product' => 'Diesel Exhaust Fluid' }.merge(details))
  end

  test 'picking a location creates the tank from the monitor profile, guessing DEF from the product text' do
    feed_tank = smartank_tank
    setup = TankSetup.new(feed_tank)
    assert_equal '901', setup.suggested_product_id

    tank = setup.apply!(location: @site, product_id: setup.suggested_product_id)
    assert_equal ['JET WRENS DEF', 2198, 1978, '901'],
                 [tank.name, tank.capacity_gallons, tank.fill_limit_gallons, tank.product_id]
    assert_equal tank, feed_tank.reload.tank
  end

  test 'the monitor takes over a copied tank of the same product, keeping its fill and bottom percentages' do
    copied = Tank.create!(location: @site, product: @def, name: 'Bulk DEF', capacity_gallons: 1000,
                          fill_limit_gallons: 850, bottom_gallons: 85)
    tank = TankSetup.new(smartank_tank).apply!(location: @site, product_id: '901')

    assert_equal copied, tank
    assert_equal [2198, 1868, 187], [tank.capacity_gallons, tank.fill_limit_gallons, tank.bottom_gallons].map(&:to_i)
    assert_equal 1, Tank.where(location: @site).count

    second = TankSetup.new(smartank_tank).apply!(location: @site, product_id: '901')
    assert_not_equal copied, second, 'a tank a monitor already feeds is never taken over'
  end

  test 'imports link a monitor tank that carries the app location number and product ID' do
    csv = KII.sub('"Five Points Service","UnAssigned","-","-","-"',
                  "\"Five Points Service\",\"UnAssigned\",\"#{@site.id}\",\"-\",\"901\"")
    result = TankFeeds::Kii.new(tank_file(csv)).import!

    tank = FeedTank.find_by!(feed: 'kii', external_id: '#FPS_A').tank
    assert_equal [@site, '901', 2198], [tank.location, tank.product_id, tank.capacity_gallons.to_i]
    assert_includes result[:warnings], "1 feed tanks linked by their monitor's location number"
    assert_equal 1, tank.feed_tanks.first.readings.count
  end

  test 'the export lists linked monitor tanks, the ones still to key in first' do
    keyed = smartank_tank('location_id' => @site.id.to_s, 'product_id' => '901', 'serial' => '907')
    TankSetup.new(keyed).apply!(location: @site, product_id: '901')
    other = Location.create!(company_name: 'TS Other', location_category_id: 2)
    pending = smartank_tank('serial' => '908')
    TankSetup.new(pending).apply!(location: other, product_id: '901')

    rows = CSV.parse(TankFeedExport.new.to_csv, headers: true)
    assert_equal [pending.external_id, keyed.external_id], rows.pluck('Monitor tank ID')
    assert_equal [other.id.to_s, 'User Defined (A)', 'No'],
                 rows.first.values_at('Location number', 'Location field', 'Monitor has location number')
    assert_equal 'Yes', rows[1]['Monitor has location number']
  end
end
