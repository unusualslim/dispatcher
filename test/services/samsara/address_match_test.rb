require 'test_helper'

module Samsara
  class AddressMatchTest < ActiveSupport::TestCase
    ADDRESSES = [
      { 'id' => '1', 'name' => 'Five Points Service - Main Office',
        'formattedAddress' => '10154 US-341, Fort Valley, GA 31030', 'latitude' => 32.5, 'longitude' => -83.8 },
      { 'id' => '2', 'name' => 'Hawkins Oil', 'formattedAddress' => '109 W Mulberry St, LaGrange, GA 30240',
        'latitude' => 33.04, 'longitude' => -85.03 },
      { 'id' => '3', 'name' => 'Jones Petroleum', 'formattedAddress' => '7665 Lee Rd, Lithia Springs, GA',
        'latitude' => 33.79, 'longitude' => -84.66 }
    ].freeze

    def match(**attrs)
      AddressMatch.new(ADDRESSES).for(Location.new(**attrs))
    end

    test 'matches by street number and street in the same city' do
      result = match(company_name: 'Five Points Service,Inc.', address: '10154 US Highway 341', city: 'Fort Valley')
      assert_equal ['1', 'street address'], [result.address['id'], result.how]
    end

    test 'matches by GPS within 300 meters' do
      result = match(company_name: 'Hawkins', address: 'PO Box 4', city: 'LaGrange', latitude: 33.0415,
                     longitude: -85.0301)
      assert_equal %w[2 GPS], [result.address['id'], result.how]
      assert_nil match(company_name: 'Elsewhere', latitude: 33.06, longitude: -85.03)
    end

    test 'falls back to the normalized name' do
      result = match(company_name: 'Jones Petroleum, Inc.', address: '7512 Lee Rd', city: 'Lithia Springs')
      assert_equal %w[3 name], [result.address['id'], result.how]
      assert_nil match(company_name: 'Nobody', address: '1 Main St', city: 'Perry')
    end
  end
end
