require 'test_helper'

class CustomerMergeTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    # The app customer, with history from the FTP order import…
    @app = Customer.create!(name: 'Mansfield', email: 'ap@mansfield.example', preferred_contact_method: 'no preference')
    @ftp_yard = Location.create!(company_name: '35 - Quik Trip Warehouse', location_category_id: 2)
    @other = Location.create!(company_name: 'Mansfield Shop', location_category_id: 2)
    @app.locations << [@ftp_yard, @other]
    @old_order = CustomerOrder.create!(customer: @app, location: @ftp_yard, order_status: 'billed')
    @quote = Quote.create!(customer: @app, status: 'draft')
    @rule = PricingRule.create!(customer: @app, name: 'Mansfield DEF', pricing_basis: PricingRule::BASES.first,
                                pricing_method: PricingRule::METHODS.first, value: 1)
    @app.phone_numbers.create!(number: '229-555-0100')

    # …and the PDI-linked twin the master data import created, with its own copy of ship-to 35.
    @pdi = Customer.create!(name: 'Mansfield Oil Company, Inc.', pdi_customer_id: '1930',
                            preferred_contact_method: 'no preference')
    @pdi_yard = Location.create!(company_name: 'Quik Trip Warehouse', address: '41 Jackson Concourse',
                                 city: 'Pendergrass', state: 'GA', zip: '30567', location_category_id: 2)
    CustomerLocation.create!(customer: @pdi, location: @pdi_yard, pdi_location_id: '35')
    @new_order = CustomerOrder.create!(customer: @pdi, location: @pdi_yard, order_status: 'open_order')
  end

  test 'moves history onto the PDI customer and folds the duplicate ship-to into the app location' do
    merge = CustomerMerge.new(@app, @pdi)
    assert_equal({ 'Orders' => 1, 'Quotes' => 1, 'Pricing rules' => 1, 'Production orders' => 0,
                   'Phone numbers' => 1, 'Locations' => 2 }, merge.counts)
    assert_equal([[@ftp_yard, @pdi_yard]], merge.locations.pairs.map { |p| [p.old_location, p.new_location] })

    merge.merge!

    assert_not Customer.exists?(@app.id)
    assert_equal([@pdi.id] * 4, [@old_order, @new_order, @quote, @rule].map { |r| r.reload.customer_id })
    assert_equal @ftp_yard.id, @new_order.location_id, 'orders on the import copy move to the kept location'
    assert_not Location.exists?(@pdi_yard.id), 'the unused import copy is deleted'
    assert_equal '35', CustomerLocation.find_by!(customer: @pdi, location: @ftp_yard).pdi_location_id
    assert_equal ['41 Jackson Concourse', 'Pendergrass', '30567', '35 - Quik Trip Warehouse'],
                 @ftp_yard.reload.values_at(:address, :city, :zip, :company_name)
    assert CustomerLocation.exists?(customer: @pdi, location: @other)
    assert_equal ['229-555-0100'], @pdi.phone_numbers.pluck(:number)
    assert_equal 'ap@mansfield.example', @pdi.reload.email
  end

  test 'keeps the import copy when another customer uses it, and refuses to merge a PDI customer away' do
    CustomerLocation.create!(customer: Customer.create!(name: 'Other', preferred_contact_method: 'no preference'),
                             location: @pdi_yard)
    CustomerMerge.new(@app, @pdi).merge!
    assert Location.exists?(@pdi_yard.id)

    error = assert_raises(ArgumentError) do
      CustomerMerge.new(@pdi, Customer.create!(name: 'X', preferred_contact_method: 'no preference'))
    end
    assert_match(/merge the other way/, error.message)
  end

  test 'pairs store-numbered locations with the PDI ship-to of that number' do
    ta = Customer.create!(name: 'TA', preferred_contact_method: 'no preference')
    cartersville = Location.create!(company_name: '146 Cartersville TA', address: '981 Cassville White Rd',
                                    city: 'Cartersville', location_category_id: 2)
    columbia = Location.create!(company_name: 'TA 238 Columbia Petro', city: 'Columbia', location_category_id: 2)
    elsewhere = Location.create!(company_name: 'TA 238 Annex', city: 'Augusta', location_category_id: 2)
    ta.locations << [cartersville, columbia, elsewhere]
    centers = Customer.create!(name: 'Travel Centers of America', pdi_customer_id: '2515',
                               preferred_contact_method: 'no preference')
    { '146' => %w[TA-Cartersville Cartersville],
      '238' => ['TA-Columbia Petro 238', 'Columbia'] }.each do |id, (name, city)|
      CustomerLocation.create!(customer: centers, pdi_location_id: id,
                               location: Location.create!(company_name: name, city: city,
                                                          address: "Travel Center ##{id}",
                                                          location_category_id: 2))
    end

    pairs = CustomerMerge.new(ta, centers).locations.pairs
    assert_equal [['146 Cartersville TA', 'TA-Cartersville'], ['TA 238 Columbia Petro', 'TA-Columbia Petro 238']],
                 pairs.map { |p| [p.old_location.company_name, p.new_location.company_name] }.sort
  end

  test 'leaves a location the PDI customer already has as a ship-to, and replaces its plain link when folding' do
    # Already PDI ship-to 11 of the target: stays as it is, not re-paired with similar-named ship-to 12.
    langdale = Location.create!(company_name: 'Langdale Fuel Co.', city: 'Valdosta', location_category_id: 2)
    @app.locations << langdale
    CustomerLocation.create!(customer: @pdi, location: langdale, pdi_location_id: '11')
    CustomerLocation.create!(customer: @pdi, pdi_location_id: '12',
                             location: Location.create!(company_name: 'Langdale Fuel Co', city: 'Valdosta',
                                                        location_category_id: 2))
    # The target also has a plain link to the app's ship-to 35 location (from an order).
    CustomerLocation.create!(customer: @pdi, location: @ftp_yard)

    CustomerMerge.new(@app, @pdi).merge!

    assert_equal '11', CustomerLocation.find_by!(customer: @pdi, location: langdale).pdi_location_id
    assert_equal ['35'], CustomerLocation.where(customer: @pdi, location: @ftp_yard).pluck(:pdi_location_id)
  end

  test 'drops empty phone numbers and ones the PDI customer already has' do
    @app.phone_numbers.create!(number: '')
    @app.phone_numbers.create!(number: '(229) 555-0199')
    @pdi.update!(phone: '229.555.0199')

    CustomerMerge.new(@app, @pdi).merge!

    assert_equal ['229-555-0100'], @pdi.phone_numbers.pluck(:number)
  end

  test 'suggests PDI customers by shared name words, ignoring FTP leftovers' do
    Customer.create!(name: 'Mansfield Energy Partners', pdi_customer_id: '1931',
                     preferred_contact_method: 'no preference')
    suggestions = CustomerMerge::Suggestions.new

    assert_equal 'Mansfield Oil Company, Inc.', suggestions.for(@app).first.customer.name
    assert_equal %w[cimarron lumber supply],
                 suggestions.words('Cimarron Lumber and Supply Co. Date/Time: 01/21/2026 11:43a')
    assert_equal %w[cummins business services], suggestions.words('Cummins Business ServicesOrder')
  end
end
