require 'test_helper'

class CustomerMergesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @app_customer = Customer.create!(name: 'Ports Petroleum', preferred_contact_method: 'no preference')
    @pdi = Customer.create!(name: 'Ports Petroleum Co. Inc.', pdi_customer_id: '2210',
                            preferred_contact_method: 'no preference')
    CustomerOrder.create!(customer: @app_customer, order_status: 'billed',
                          location: Location.create!(company_name: '35 - Quik Trip', location_category_id: 2))
  end

  test 'admin reviews a suggested match, previews it and merges' do
    sign_in User.create!(email: 'admin-merge@example.com', password: 'password123', role: 'admin')

    get customer_merges_path
    assert_select 'a[href=?]', new_customer_merge_path(source_id: @app_customer.id, target_id: @pdi.id),
                  /Ports Petroleum Co\. Inc\. \[PDI 2210\]/

    get new_customer_merge_path(source_id: @app_customer.id, target_id: @pdi.id)
    assert_response :success
    assert_includes response.body, '1 orders'

    get targets_customer_merges_path(q: '2210')
    assert_equal ['Ports Petroleum Co. Inc. [PDI 2210]'], response.parsed_body.pluck('text')

    post customer_merges_path, params: { source_id: @app_customer.id, target_id: @pdi.id }
    assert_redirected_to customer_merges_path
    assert_match(/Merged Ports Petroleum into Ports Petroleum Co\. Inc\. \(1 orders, 1 locations\)/, flash[:notice])
    assert_not Customer.exists?(@app_customer.id)
    assert_equal 1, @pdi.customer_orders.count
  end

  test 'staff cannot merge' do
    sign_in User.create!(email: 'sales-merge@example.com', password: 'password123', role: 'staff',
                         permissions: { 'sales' => 'approve' })
    post customer_merges_path, params: { source_id: @app_customer.id, target_id: @pdi.id }
    assert_response :redirect
    assert Customer.exists?(@app_customer.id)
  end
end
