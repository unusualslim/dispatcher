require 'test_helper'
require Rails.root.join('test/support/tank_feed_files').to_s

class TankFeedsTest < ActiveSupport::TestCase
  include TankFeedFiles

  test 'Kii: FPS sensors are tracked, others ignored; times are UTC; re-importing adds nothing' do
    path = tank_file(KII)
    summary = TankFeeds::Kii.new(path).summary
    assert_equal 3, summary.feed_tanks
    assert_equal 1, summary.new_readings, 'the coolant row has no level'
    assert_equal 1, summary.unreadable

    result = TankFeeds::Kii.new(path).import!
    assert_equal 1, result[:created]
    ours = FeedTank.find_by!(feed: 'kii', external_id: '#FPS_A')
    assert_not ours.ignored
    assert FeedTank.find_by!(feed: 'kii', external_id: '#PBO_B').ignored
    assert_equal Time.utc(2026, 11, 9, 4, 35), ours.last_read_at
    assert_in_delta 1200.5, ours.last_gallons
    assert_in_delta 0.26, ours.readings.first.water_inches

    assert_equal 0, TankFeeds::Kii.new(path).import![:created]
  end

  test 'Smartank: header found under the info rows, Eastern times, retired and inactive tanks ignored' do
    TankFeeds::Smartank.new(tank_file(SMARTANK)).import!
    thomson = FeedTank.find_by!(feed: 'smartank', external_id: '1001')
    assert_equal 'JET THOMSON DEF', thomson.name
    assert_equal Time.find_zone('America/New_York').local(2026, 11, 10, 1, 53), thomson.last_read_at
    assert_in_delta 1343.5, thomson.last_gallons
    assert_equal '2,198', thomson.details['capacity']
    assert FeedTank.find_by!(feed: 'smartank', external_id: '1002').ignored, 'z- name'
    assert FeedTank.find_by!(feed: 'smartank', external_id: '1003').ignored, 'Active False'
  end

  test '0002: time from the file name, DI Water ignored, nameless lines skipped' do
    TankFeeds::Plant0002.new(tank_file(PLANT_0002), file_name: 'FPS_TANKS_0002_20261111_0600.txt').import!
    tanks = FeedTank.in_feed('plant_0002')
    assert_equal ['DI Water', 'P-1', 'T-8 500 K', 'Tank 1', 'Tank 11'], tanks.order(:name).pluck(:name)
    assert tanks.find_by(name: 'DI Water').ignored
    assert_equal [Time.find_zone('America/New_York').local(2026, 11, 11, 6)],
                 TankReading.joins(:feed_tank).merge(tanks).distinct.pluck(:read_at)
    assert_in_delta 391_883, tanks.where(ignored: false).sum(:last_gallons)
  end

  test '0002: a saved email is read by its sent time, ignoring the banner and the hidden preview line' do
    TankFeeds::Plant0002.new(tank_file(plant_0002_email, 'tanks.eml'), file_name: 'FPS_TANKS_0002_x.eml').import!
    tanks = FeedTank.in_feed('plant_0002')

    assert_equal ['DI Water', 'P-1', 'T-8 500 K', 'Tank 1', 'Tank 11', 'Tank 99'], tanks.order(:name).pluck(:name)
    assert_equal [Time.find_zone('America/New_York').local(2026, 11, 8, 23, 54, 54)],
                 TankReading.joins(:feed_tank).merge(tanks).distinct.pluck(:read_at), 'sent date, not the subject date'
    assert_equal [1049], tanks.where(name: 'Tank 1').pluck(:last_gallons).map(&:to_i)
  end

  test '0002: an email is recognised by its content when the file name has no .eml' do
    reading = TankFeeds::Plant0002.new(tank_file(plant_0002_email, 'upload.bin')).rows

    assert_equal 6, reading.size
    assert_equal [Time.find_zone('America/New_York').local(2026, 11, 8, 23, 54, 54)], reading.map(&:read_at).uniq
  end

  test '0002 needs a reading time' do
    assert_raises(ArgumentError) { TankFeeds::Plant0002.new(tank_file(PLANT_0002, 'tanks.txt')).rows }
  end

  test 'a tank adds up its linked feed tanks and defaults its limits' do
    TankFeeds::Plant0002.new(tank_file(PLANT_0002), file_name: 'FPS_TANKS_0002_20261111_0600.txt').import!
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    tank = Tank.create!(location: Location.create!(company_name: 'Plant', location_category_id: 1), name: 'Bulk DEF',
                        capacity_gallons: 600_000, ownership: 'ours')
    FeedTank.in_feed('plant_0002').find_each { |ft| ft.update!(tank: tank) }

    assert_equal 540_000, tank.fill_limit_gallons
    assert_equal 54_000, tank.bottom_gallons
    assert_in_delta 391_883, tank.reload.current_gallons, 0.01, 'DI Water stays out'
    assert_in_delta 148_117, tank.safe_ullage, 0.01
  end

  test 'spreadsheet history: a reading at 6 AM Eastern per typed inventory' do
    TankFeeds::SpreadsheetHistory.new(tank_file(SPREADSHEET)).import!
    wrens = FeedTank.find_by!(feed: 'spreadsheet', external_id: 'WRENS')
    assert_equal 'JET WRENS', wrens.name
    assert_equal 2, wrens.readings.count
    assert_equal Time.find_zone('America/New_York').local(2026, 10, 28, 6), wrens.last_read_at
  end
end
