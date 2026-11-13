require 'test_helper'
require Rails.root.join('test/support/tank_feed_files').to_s

# Dispatch → Tanks / Tank Feeds and Data Imports → Tank Readings.
class TanksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include TankFeedFiles

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @site = Location.create!(company_name: 'Molly\'s Thomson', city: 'Thomson', location_category_id: 2)
    @def = Product.create!(id: 'TT-DEF', name: 'Bulk DEF')
    @admin = User.create!(email: 'tanks-admin@example.com', password: 'password123', role: 'admin')
    TankFeeds::Smartank.new(tank_file(SMARTANK)).import!
    @thomson = FeedTank.find_by!(feed: 'smartank', external_id: '1001')
  end

  test 'a dispatcher sets up a tank from a waiting feed tank and sees its level' do
    sign_in staff_user('tanks-dispatch@example.com', { 'dispatch' => 'edit' })

    get feed_tanks_path
    assert_response :success
    assert_select 'td', text: /JET THOMSON DEF/
    assert_select 'h6 a', text: 'Smartank'

    get new_tank_path(feed_tank_id: @thomson.id)
    assert_select 'input[name="tank[name]"][value="JET THOMSON DEF"]'
    assert_select 'input[name="tank[capacity_gallons]"][value="2198"]'

    post tanks_path, params: { feed_tank_id: @thomson.id, return_to: 'feeds',
                               tank: { name: 'DEF', location_id: @site.id, product_id: @def.id, ownership: 'managed',
                                       capacity_gallons: 2198, active: '1' } }
    assert_redirected_to feed_tanks_path
    tank = Tank.find_by!(name: 'DEF')
    assert_equal tank, @thomson.reload.tank
    assert_equal 1978, tank.fill_limit_gallons

    get tanks_path
    assert_select 'td', text: '1,344 gal'
    get tank_path(tank)
    assert_response :success
    assert_select 'td', text: /Smartank: JET THOMSON DEF/
  end

  test 'feed tanks are linked to an existing tank or ignored' do
    sign_in staff_user('tanks-link@example.com', { 'dispatch' => 'edit' })
    tank = Tank.create!(location: @site, name: 'DEF', capacity_gallons: 2198)

    patch feed_tank_path(@thomson), params: { feed_tank: { tank_id: tank.id } }
    assert_equal tank, @thomson.reload.tank

    farm = FeedTank.find_by!(external_id: '1003')
    patch feed_tank_path(farm), params: { feed_tank: { ignored: false } }
    assert_not farm.reload.ignored
    assert_equal 1, FeedTank.needs_setup.count
  end

  test 'manual readings for tanks without a monitor' do
    sign_in staff_user('tanks-manual@example.com', { 'dispatch' => 'edit' })
    tank = Tank.create!(location: @site, name: 'DEF 2', capacity_gallons: 1000)

    post record_reading_tank_path(tank), params: { gallons: '640', read_at: '2026-11-11T09:15' }
    assert_redirected_to tank_path(tank)
    manual = tank.feed_tanks.find_by!(feed: 'manual')
    assert_equal Time.find_zone('America/New_York').local(2026, 11, 11, 9, 15), manual.last_read_at
    assert_in_delta 640, tank.reload.current_gallons
  end

  test 'viewers can look but not change; drivers are kept out' do
    sign_in staff_user('tanks-view@example.com', { 'dispatch' => 'view' })
    get tanks_path
    assert_response :success
    patch feed_tank_path(@thomson), params: { feed_tank: { ignored: true } }
    assert_not @thomson.reload.ignored

    sign_in User.create!(email: 'tanks-driver@example.com', password: 'password123', role: 'worker')
    get tanks_path
    assert_response :redirect
  end

  test 'admins import a feed file by hand: preview, then import' do
    sign_in @admin
    get new_tank_feed_import_path
    assert_response :success

    upload = Rack::Test::UploadedFile.new(tank_file(PLANT_0002, 'tanks.txt'), 'text/plain')
    post preview_tank_feed_import_path, params: { feed: 'plant_0002', read_at: '2026-11-11T06:00', file: upload }
    assert_response :success
    assert_select 'tr.table-success td', text: '4'

    post tank_feed_import_path
    assert_redirected_to new_tank_feed_import_path
    assert_equal 4, TankReading.joins(:feed_tank).merge(FeedTank.in_feed('plant_0002')).count
    assert_equal 'success', SyncLog.find_by!(process_name: 'Tank Feed Import (0002 tank email)').status
  end
end
