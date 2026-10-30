require 'test_helper'

class CustomerOrderFormTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  fixtures :users, :customers, :products, :locations, :location_categories

  setup do
    sign_in users(:admin_user)
    @customer = customers(:acme)
    @product  = products(:def_finished)
    @quote = Quote.create!(customer: @customer, locks_pricing: true, valid_from: Date.today, expiry_date: Date.today + 30,
                           quote_products_attributes: [{ product_id: @product.id, quantity: 10, price: 4.75 }])
    @quote.accept!(users(:admin_user))
    @line = @quote.quote_products.first
  end

  test 'creating an order without a location re-renders the form with an error' do
    assert_no_difference -> { CustomerOrder.count } do
      post customer_orders_path, params: { customer_order: {
        customer_id: @customer.id, location_id: '',
        customer_order_products_attributes: { '0' => { product_id: @product.id, quantity: 10, price: '4.75', quote_product_id: @line.id } }
      } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, 'Location must exist'
    assert_includes response.body, %(value="#{@line.id}" class="price-source-quote"), 'quote link is kept'
  end

  test 'creating an order at a disabled location re-renders the form with an error' do
    location = locations(:terminal)
    location.update_column(:disabled, true)

    assert_no_difference -> { CustomerOrder.count } do
      post customer_orders_path, params: { customer_order: { customer_id: @customer.id, location_id: location.id } }
    end
    assert_response :unprocessable_content
    assert_includes response.body, 'currently disabled'
  end

  test 'a failed order update re-renders the edit form' do
    order = CustomerOrder.create!(customer: @customer, location: locations(:terminal), order_status: 'Open Order')

    patch customer_order_path(order), params: { customer_order: { location_id: '' } }
    assert_response :unprocessable_content
    assert_includes response.body, 'Location must exist'
  end

  def search(params)
    get search_locations_path, params: params, headers: { 'Accept' => 'application/json' }
    assert_response :success
    JSON.parse(response.body)
  end

  # The app treats location_category_id 2 as "destination" (as in production).
  def destination_category
    LocationCategory.find_by(id: 2) || LocationCategory.create!(id: 2, name: 'Destination')
  end

  def make_destination(name, city)
    destination_category
    Location.create!(company_name: name, city: city, location_category_id: 2)
  end

  test "location search lists the customer's locations first, then all matches" do
    shared  = make_destination('Shared Truck Stop', 'Americus')
    own     = make_destination('Acme Americus Yard', 'Americus')
    other   = make_destination('Other Americus Depot', 'Americus')
    river   = customers(:river_transport)
    CustomerLocation.create!(customer: @customer, location: shared)
    CustomerLocation.create!(customer: @customer, location: own)
    CustomerLocation.create!(customer: river, location: shared)

    # Nothing typed: only the customer's own locations
    data = search(customer_id: @customer.id)
    assert_equal 1, data['results'].size
    assert_equal "Locations for #{@customer.name}", data['results'][0]['text']
    assert_equal([own.id, shared.id], data['results'][0]['children'].map { |c| c['id'] })
    assert_equal [own.id, shared.id].sort, data['customer_location_ids'].sort

    # Typing: customer's matches grouped first, then other matches (no duplicates)
    data = search(customer_id: @customer.id, query: 'americus')
    assert_equal(["Locations for #{@customer.name}", 'All locations'], data['results'].map { |g| g['text'] })
    assert_equal([own.id, shared.id], data['results'][0]['children'].map { |c| c['id'] })
    assert_includes data['results'][1]['children'].map { |c| c['id'] }, other.id
    assert_not_includes data['results'][1]['children'].map { |c| c['id'] }, shared.id

    # A shared location shows up for the other customer too
    data = search(customer_id: river.id)
    assert_equal([shared.id], data['results'][0]['children'].map { |c| c['id'] })

    # No customer: flat search results, nothing before typing
    assert_empty search({})['results']
    assert_includes search(query: 'americus')['results'].map { |r| r['id'] }, other.id
  end

  test 'saving an order links its customer to the location, without duplicates' do
    site  = make_destination('Acme Leesburg', 'Leesburg')
    other = make_destination('Acme Dawson', 'Dawson')

    order = CustomerOrder.create!(customer: @customer, location: site, order_status: 'Open Order')
    assert_includes @customer.reload.locations, site

    CustomerOrder.create!(customer: @customer, location: site, order_status: 'Open Order')
    assert_equal 1, CustomerLocation.where(customer: @customer, location: site).count

    order.update!(location: other)
    assert_includes @customer.reload.locations, other

    # A shared location: a second customer ordering there gets linked too
    river = customers(:river_transport)
    CustomerOrder.create!(customer: river, location: site, order_status: 'Open Order')
    assert_equal [@customer.id, river.id].sort, site.reload.customers.pluck(:id).sort
  end

  test 'a destination created from the order form is linked to the customer' do
    destination_category
    post locations_path, params: { location: { company_name: 'New Site', city: 'Leslie', location_category_id: 2 },
                                   customer_id: @customer.id }, as: :json
    assert_response :created
    assert_includes @customer.reload.locations.pluck(:company_name), 'New Site'
  end

  test "order from a quote without a location pre-fills the customer's first location" do
    location = locations(:terminal)
    CustomerLocation.create!(customer: @customer, location: location)

    get new_customer_order_path(from_quote: @quote.id)
    assert_response :success
    assert_includes response.body, %(name="customer_order[location_id]"\n                   value="#{location.id}")
  end
end
