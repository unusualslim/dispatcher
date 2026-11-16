require 'test_helper'

class TankCopyTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @site = Location.create!(company_name: 'TC Site', location_category_id: 2)
    @def = Product.find_by(id: '901') || Product.create!(id: '901', name: 'Bulk DEF')
    @fps001 = Product.find_by(id: 'FPS001') || Product.create!(id: 'FPS001', name: 'DEF (bulk)')
  end

  test 'copies capacity and percentages, maps FPS001 to 901 and 70 to 527, skips fuel and existing tanks' do
    old_site = Location.create!(id: 70, company_name: 'Use 527 per LP', location_category_id: 2)
    new_site = Location.create!(id: 527, company_name: 'Renumbered site', location_category_id: 2)
    fuel = Product.find_by(id: 'FPS011') || Product.create!(id: 'FPS011', name: 'Dyed ULSD')
    covered = Location.create!(company_name: 'TC Monitored', location_category_id: 2)
    Tank.create!(location: covered, product: @def, name: 'Monitor tank', capacity_gallons: 3000)

    LocationProduct.create!(location: @site, product: @fps001, max_capacity: 2000, 'uleage_90' => 85, cutoff: 5)
    LocationProduct.create!(location: old_site, product: @def, max_capacity: 1000)
    LocationProduct.create!(location: @site, product: fuel, max_capacity: 8000)
    LocationProduct.create!(location: covered, product: @def, max_capacity: 3000)
    LocationProduct.create!(location: @site, product: @def, quantity: 0) # no capacity: not a tank row

    copy = TankCopy.new
    assert_equal 2, copy.to_create.size
    assert_equal 'Fuel tank (leaves with the fuel company)', copy.plans.find { |p| p.row.product_id == 'FPS011' }.skip
    copy.run!

    site_tank = Tank.find_by!(location: @site)
    assert_equal '901', site_tank.product_id
    assert_equal [2000, 1700, 85], [site_tank.capacity_gallons, site_tank.fill_limit_gallons, site_tank.bottom_gallons]
    renumbered = Tank.find_by!(location: new_site)
    assert_equal [1000, 900, 90],
                 [renumbered.capacity_gallons, renumbered.fill_limit_gallons, renumbered.bottom_gallons]
    assert_not Tank.exists?(location: old_site)

    assert_empty TankCopy.new.to_create, 'running it again creates nothing'
  end
end
