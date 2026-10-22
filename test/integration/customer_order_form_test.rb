require "test_helper"

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

  test "creating an order without a location re-renders the form with an error" do
    assert_no_difference -> { CustomerOrder.count } do
      post customer_orders_path, params: { customer_order: {
        customer_id: @customer.id, location_id: '',
        customer_order_products_attributes: { '0' => { product_id: @product.id, quantity: 10, price: '4.75', quote_product_id: @line.id } }
      } }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, 'Location must exist'
    assert_includes response.body, %(value="#{@line.id}" class="price-source-quote"), 'quote link is kept'
  end

  test "creating an order at a disabled location re-renders the form with an error" do
    location = locations(:terminal)
    location.update_column(:disabled, true)

    assert_no_difference -> { CustomerOrder.count } do
      post customer_orders_path, params: { customer_order: { customer_id: @customer.id, location_id: location.id } }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, 'currently disabled'
  end

  test "a failed order update re-renders the edit form" do
    order = CustomerOrder.create!(customer: @customer, location: locations(:terminal), order_status: 'Open Order')

    patch customer_order_path(order), params: { customer_order: { location_id: '' } }
    assert_response :unprocessable_entity
    assert_includes response.body, 'Location must exist'
  end

  test "order from a quote without a location pre-fills the customer's first location" do
    location = locations(:terminal)
    CustomerLocation.create!(customer: @customer, location: location)

    get new_customer_order_path(from_quote: @quote.id)
    assert_response :success
    assert_includes response.body, %(name="customer_order[location_id]"\n                   value="#{location.id}")
  end
end
