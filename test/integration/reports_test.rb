require 'test_helper'

class ReportsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :products, :locations, :location_categories

  def staff(permissions)
    User.create!(email: "staff-#{SecureRandom.hex(3)}@example.com", password: 'password123', role: 'staff',
                 permissions: permissions)
  end

  setup do
    customer = Customer.create!(name: 'Acme', preferred_contact_method: 'no preference')
    order = CustomerOrder.create!(external_order_no: 'OD-7', order_status: 'billed', customer: customer,
                                  location: locations(:terminal), order_date: Date.new(2026, 10, 1),
                                  required_delivery_date: Date.new(2026, 10, 2), invoice_date: Date.new(2026, 10, 4))
    order.customer_order_products.create!(product_id: products(:urea).id, product_name: products(:urea).id,
                                          quantity: 10, price: 5)
  end

  test 'staff see the reports for their areas, with filters, totals and CSV' do
    sign_in staff('sales' => 'view')

    get reports_path
    assert_response :success
    assert_select 'a.card', text: /Sales by customer/
    assert_select 'a.card', text: /Inventory movements/, count: 0

    get report_path('sales_by_customer', from: '2026-10-01', to: '2026-10-31')
    assert_response :success
    assert_select 'tbody td', text: 'Acme'
    assert_select 'tfoot td', text: '$50.00'

    get report_path('late_orders', from: '2026-10-01', to: '2026-10-31', format: :csv)
    assert_equal ['OD-7', 'Acme', 'Columbus Terminal', '2026-10-01', '2026-10-02', '2026-10-04', '3', '2'],
                 CSV.parse(response.body)[1]

    get report_path('inventory_movements')
    assert_response :redirect
  end

  test 'filters default to this month and keep their values' do
    filters = Reports::Filters.new(ActionController::Parameters.new(customer_id: '5'), Reports::SalesByCustomer,
                                   Date.new(2026, 10, 27))

    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 27), filters.range
    assert_equal '5', filters[:customer_id]
    assert_equal Date.new(2025, 10, 1), Reports::SalesByMonth.default_from(Date.new(2026, 10, 27))
  end
end
