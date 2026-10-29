require 'test_helper'

class DispatchOriginTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    @yard = Location.create!(company_name: 'Dor Service', address: '10154 US Highway 341 S', city: 'Dor Valley',
                             state: 'GA', zip: '31030', location_category_id: 1)
    @fountain = Location.create!(company_name: 'Dor Service - Fountain St', address: '213 Fountain St',
                                 city: 'Dor Valley', state: 'GA', zip: '31030', location_category_id: 1)
  end

  test 'a dispatch links its origin terminal when saved, and keeps it after the location is renamed' do
    dispatch = Dispatch.create!(origin: @yard.full_address_with_company)
    assert_equal @yard, dispatch.origin_location

    @yard.update!(company_name: 'Dor Service Renamed', address: '10154 Hwy 341')
    assert_equal @yard, dispatch.reload.origin_location
  end

  test 'old text snapshots match by city and street address' do
    terminals = [@yard, @fountain]
    assert_equal @yard,
                 DispatchOrigin.resolve('Dor Service,Inc. - 10154 US Highway 341 Dor Valley, GA 31030', terminals)
    assert_equal @fountain, DispatchOrigin.resolve('Dor Service - Fountain St Dor Valley, GA', terminals)
    assert_equal @yard, DispatchOrigin.resolve('Dor Valley', [@yard])
    assert_nil DispatchOrigin.resolve('Elsewhere - 1 Main St Nowhere, GA', terminals)
  end
end
