require 'test_helper'

class LocationMergeBulkTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @customer = Customer.create!(name: 'Busy Bee', pdi_customer_id: '1820', preferred_contact_method: 'no preference')
  end

  def link(name, pdi: nil, **attrs)
    location = Location.create!(company_name: name, location_category_id: 2, **attrs)
    CustomerLocation.create!(customer: @customer, location: location, pdi_location_id: pdi)
  end

  test 'confidence: same name at the same street is 100; store number and partial matches score lower' do
    keep = link('Busy Bee 25', pdi: '13', address: '1605 US-129', city: 'Live Oak', zip: '32064')

    same = LocationMerge::Confidence.new(keep, link('BUSY BEE 25.', address: '1605 US 129', city: 'Live Oak'))
    assert_equal [100, ['same street address', 'same name']], [same.score, same.reasons]

    store = LocationMerge::Confidence.new(keep, link('Travel Center #13', city: 'Live Oak'))
    assert_equal [70, ['store number = PDI ship-to 13', 'same city, one has no address']], [store.score, store.reasons]

    renamed = LocationMerge::Confidence.new(keep, link('Busy Bee Live Oak', address: '1605 US-129', zip: '32064'))
    assert_equal 100, renamed.score, 'same street + a shared name word'
    unrelated = LocationMerge::Confidence.new(keep, link('Richland', address: '1605 US-129', zip: '32064'))
    assert_equal [90, ['same street address']], [unrelated.score, unrelated.reasons]

    loose = LocationMerge::Confidence.new(keep, link('Busy Bee Truck Wash', address: '9 Oak St', zip: '32064'))
    assert_operator loose.score, :<, 60
  end

  test 'bulk merges overlapping pairs of three copies into one, skipping what is already merged' do
    a = link('Busy Bee 25', pdi: '13', address: '1605 US-129', city: 'Live Oak').location
    b = link('Busy Bee 25', address: '1605 US-129', city: 'Live Oak').location
    c = link('Busy Bee #25', city: 'Live Oak').location
    CustomerOrder.create!(customer: @customer, location: c, order_status: 'billed')

    result = LocationMerge::Bulk.new([[b.id, a.id], [c.id, a.id], [c.id, b.id]]).run

    assert_equal [2, 1, []], [result.merged, result.skipped, result.errors]
    assert_equal [a.id], CustomerLocation.where(customer: @customer).pluck(:location_id)
    assert_equal a.id, CustomerOrder.find_by!(customer: @customer).location_id
  end

  test 'one refused pair is reported and the rest still merge' do
    a = link('Busy Bee 14', pdi: '12', city: 'Jasper').location
    b = link('Busy Bee 14 old', pdi: '99', city: 'Jasper').location
    c = link('Busy Bee 14', city: 'Jasper').location

    result = LocationMerge::Bulk.new([[b.id, a.id], [c.id, a.id]]).run

    assert_equal 1, result.merged
    assert_match(/separate PDI ship-tos/, result.errors.sole)
    assert Location.exists?(b.id)
  end
end
