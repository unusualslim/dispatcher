require 'test_helper'

class OversellTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @warehouse = Location.create!(company_name: 'OS Warehouse', location_category_id: 1, pdi_site_code: '0002')
    @site = Location.create!(company_name: 'OS Customer', location_category_id: 2)
    @customer = Customer.create!(name: 'OS Customer', preferred_contact_method: 'no preference')
    @fitting = Product.create!(id: 'OS-FIT', name: 'Hose fitting', is_raw_material: false, category: 'HYDRAULICS')
    ReportingGroup.find_by!(name: 'HYDRAULICS').update!(buy: true)
    LocationProduct.create!(location: @warehouse, product: @fitting, quantity: 10)
    sign_in User.create!(email: 'os-admin@example.com', password: 'password123', role: 'admin')
  end

  def order_params(quantity)
    { customer_order: { customer_id: @customer.id, location_id: @site.id, ship_from_location_id: @warehouse.id,
                        customer_order_products_attributes: { '0' => { product_id: @fitting.id, quantity: quantity,
                                                                       price: 5 } } } }
  end

  test 'an app order cannot take more of a bought item than the warehouse has left' do
    assert_difference('CustomerOrder.count') { post customer_orders_path, params: order_params(6) }
    assert_no_difference('CustomerOrder.count') { post customer_orders_path, params: order_params(5) }
    assert_response :unprocessable_content
    assert_includes response.body,
                    'OS-FIT Hose fitting: ordering 5, only 4 available (10 on hand, 6 on other open orders)'

    order = CustomerOrder.last
    patch customer_order_path(order), params: { customer_order: { notes: 'Call first' } }
    assert_redirected_to customer_order_path(order), 'unchanged lines are not re-checked'
  end
end
