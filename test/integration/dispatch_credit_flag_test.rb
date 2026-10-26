require 'test_helper'

# The dispatch board flags customers PDI reports over their credit limit (snapshot from the order sync).
class DispatchCreditFlagTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  test 'order sync records the credit snapshot and the board shows a Credit badge only for that customer' do
    PdiOrderApiImportService.call(file_fixture('pdi_orders.xml').read)
    spc = Customer.find_by!(pdi_customer_id: '2362')
    assert_equal ['Credit Hold', BigDecimal('250000'), BigDecimal('-53727.98')],
                 spc.values_at(:pdi_credit_status, :pdi_credit_limit, :pdi_available_credit)
    assert spc.over_credit?

    yard = Location.create!(company_name: 'Credit Yard', location_category_id: 2)
    good = Customer.create!(name: 'Paid Up Inc', preferred_contact_method: 'no preference',
                            pdi_credit_status: 'Good', pdi_available_credit: 500)
    held = CustomerOrder.create!(customer: spc, location: yard, order_status: 'open_order',
                                 required_delivery_date: Date.current)
    fine = CustomerOrder.create!(customer: good, location: yard, order_status: 'open_order',
                                 required_delivery_date: Date.current)

    sign_in User.create!(email: 'admin-credit@example.com', password: 'password123', role: 'admin')
    get kanban_dispatches_path

    assert_response :success
    assert_select "a[href='#{customer_order_path(held)}'] .badge.bg-danger", 'Credit'
    assert_select "a[href='#{customer_order_path(held)}'] .badge.bg-danger[title*='available -$53,727.98']"
    assert_select "a[href='#{customer_order_path(fine)}'] .badge.bg-danger", count: 0
  end
end
