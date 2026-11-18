require 'test_helper'

class CustomerItemNumbersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @customer = Customer.create!(name: 'Parts Central', preferred_contact_method: 'no preference')
    @product = Product.create!(id: 'CIN-901', name: 'Bulk DEF')
    sign_in User.create!(email: 'cin-admin@example.com', password: 'password123', role: 'admin')
  end

  test 'a customer part number is kept on the customer and printed on the quote' do
    post customer_customer_item_numbers_path(@customer), params: { product_id: @product.id, part_number: 'PC-DEF-1' }
    assert_redirected_to customer_path(@customer)
    assert_equal({ @product.id => 'PC-DEF-1' }, CustomerItemNumber.map_for(@customer.id))

    post customer_customer_item_numbers_path(@customer), params: { product_id: 'NOPE', part_number: 'X' }
    assert_equal 'No product NOPE.', flash[:alert]

    get customer_path(@customer)
    assert_select 'td', text: 'PC-DEF-1'

    quote = Quote.create!(customer: @customer, status: 'draft')
    quote.quote_products.create!(product: @product, price: 3)
    get print_quote_path(quote)
    assert_select '.cust-pn', text: 'Your #: PC-DEF-1'
  end
end
