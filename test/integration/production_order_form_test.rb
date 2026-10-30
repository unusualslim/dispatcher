require 'test_helper'

class ProductionOrderFormTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  fixtures :products, :customers, :locations, :location_categories

  setup do
    sign_in User.create!(email: 'admin-poform@example.com', password: 'password123', role: 'admin')
    @po = ProductionOrder.create!(product: products(:def_finished), customer: customers(:acme),
                                  location: locations(:warehouse))
  end

  test 'edit form renders the current product, customer and location in the pickers' do
    get edit_production_order_path(@po)
    assert_response :success
    assert_select '#product_search option[selected][value=?]', @po.product_id
    assert_select '#customer_search option[selected][value=?]', @po.customer_id.to_s
    assert_select '#location_search option[selected][value=?]', @po.location_id.to_s
  end

  test 'placeholder ids from a failed lookup keep the current links' do
    patch production_order_path(@po), params: { production_order: {
      product_id: '#undefined', customer_id: '#undefined', location_id: '#undefined', total_qty_produced: '1760'
    } }

    assert_redirected_to production_order_path(@po)
    @po.reload
    assert_equal [products(:def_finished).id, customers(:acme).id, locations(:warehouse).id],
                 [@po.product_id, @po.customer_id, @po.location_id]
    assert_equal 1760, @po.total_qty_produced
  end
end
