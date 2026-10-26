require 'test_helper'

class LocationMergeTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @customer = Customer.create!(name: 'Travel Centers of America', pdi_customer_id: '2515',
                                 preferred_contact_method: 'no preference')
    @keep = Location.create!(company_name: '177 Savannah TA', city: 'Richmond Hill', location_category_id: 2,
                             notes: 'Gate code 1234')
    @dupe = Location.create!(company_name: 'TA Travel Center', address: '4401 US-17', city: 'Richmond Hill',
                             state: 'GA', zip: '31324', latitude: 31.9, longitude: -81.3, location_category_id: 2,
                             notes: 'Ask for Bob')
    CustomerLocation.create!(customer: @customer, location: @keep, pdi_location_id: '177')
    CustomerLocation.create!(customer: @customer, location: @dupe)
    @product = Product.create!(id: 'LM-DEF', name: 'Bulk DEF')
  end

  test 'moves everything onto the kept location, combines stock, fills blanks and deletes the duplicate' do
    order = CustomerOrder.create!(customer: @customer, location: @dupe, order_status: 'billed')
    quote = Quote.create!(customer: @customer, location: @dupe, status: 'draft')
    other = Customer.create!(name: 'Jet Foods', preferred_contact_method: 'no preference')
    CustomerLocation.create!(customer: other, location: @dupe)
    LocationProduct.create!(location: @keep, product: @product, quantity: 100, max_capacity: 6000)
    LocationProduct.create!(location: @dupe, product: @product, quantity: 50, 'uleage_90' => 5400)
    InventoryTransaction.create!(product: @product, location_id: @dupe.id, quantity: 50, direction: 'in')

    merge = LocationMerge.new(@dupe, @keep)
    assert_equal 1, merge.counts['Orders']
    merge.merge!

    assert_not Location.exists?(@dupe.id)
    assert_equal [@keep.id] * 2, [order.reload.location_id, quote.reload.location_id]
    assert_equal 1, InventoryTransaction.where(location_id: @keep.id).count
    stock = LocationProduct.find_by!(location: @keep, product: @product)
    assert_equal [150, 6000, 5400], [stock.quantity.to_i, stock.max_capacity, stock.uleage_90]
    assert_equal ['4401 US-17', 'GA', '31324', 31.9], @keep.reload.values_at(:address, :state, :zip, :latitude)
    assert_equal "Gate code 1234\n\nAsk for Bob", @keep.notes
    assert_equal ['177'], CustomerLocation.where(customer: @customer, location: @keep).pluck(:pdi_location_id)
    assert CustomerLocation.exists?(customer: other, location: @keep)
  end

  test 'carries the PDI ship-to link when only the removed location had it' do
    LocationMerge.new(@keep, @dupe).merge!

    assert_equal ['177'], CustomerLocation.where(customer: @customer, location: @dupe).pluck(:pdi_location_id)
  end

  test 'refuses two different PDI ship-tos of one customer, and locations of different types' do
    CustomerLocation.find_by!(location: @dupe).update!(pdi_location_id: '178')
    error = assert_raises(ArgumentError) { LocationMerge.new(@dupe, @keep) }
    assert_match(/separate PDI ship-tos \(178 and 177\)/, error.message)

    terminal = Location.create!(company_name: 'Bainbridge Terminal', location_category_id: 1)
    assert_raises(ArgumentError) { LocationMerge.new(terminal, @keep) }
  end

  test 'suggests same-city duplicates for one customer, keeping the PDI-linked one' do
    shop = Location.create!(company_name: 'B & B Trucking', address: '1374 Cool Springs Rd', city: 'Richmond Hill',
                            location_category_id: 2)
    stop = Location.create!(company_name: '76 Truck Stop', address: '100 GA Hwy 49', city: 'Richmond Hill',
                            location_category_id: 2)
    @customer.locations << [shop, stop]
    @keep.update!(address: '4401 US 17')

    pairs = LocationMerge::Suggestions.new.pairs.select { |p| p.customer == @customer }

    assert_equal [[@keep, @dupe]], pairs.map { |p| [p.keep, p.remove] }, 'same street; unrelated businesses left out'
  end
end
