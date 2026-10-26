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
