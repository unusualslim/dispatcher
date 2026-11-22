require 'test_helper'

# Customer Orders → Status filter: a checklist grouped by CustomerOrder::STATUS_GROUPS.
class CustomerOrderStatusFilterTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @customer = Customer.create!(name: 'Status Co')
    @site = Location.create!(company_name: 'Status Site', city: 'Albany', location_category_id: 2)
    { 'ST-1' => 'Open Order', 'ST-2' => 'Dispatched', 'ST-3' => 'Shipped', 'ST-4' => 'Billed',
      'ST-5' => 'Cancelled as Order', 'ST-6' => 'Released for Billing' }.each do |number, status|
      CustomerOrder.create!(customer: @customer, location: @site, external_order_no: number, order_status: status)
    end
    sign_in User.create!(email: 'status-filter@example.com', password: 'password123', role: 'admin')
  end

  def listed
    css_select('table.order-list-table tbody tr td[data-col="order"] a').map(&:text).sort
  end

  test 'every status belongs to exactly one group' do
    assert_equal CustomerOrder.order_statuses.values.sort, CustomerOrder::STATUS_GROUPS.values.flatten.sort
  end

  test 'checking Open shows the active statuses; the button names the groups' do
    get customer_orders_path(filtered: 1)
    assert_select '#order-status-dropdown button', text: 'Any status'
    assert_select 'input.status-group-toggle', count: CustomerOrder::STATUS_GROUPS.size
    assert_equal %w[ST-1 ST-2 ST-3 ST-4 ST-5 ST-6], listed

    get customer_orders_path(filtered: 1, statuses: CustomerOrder::STATUS_GROUPS['Open'])
    assert_equal %w[ST-1 ST-2 ST-6], listed
    assert_select '#order-status-dropdown button', text: 'Open'
    assert_select 'input.status-option[value="Open Order"][checked]'

    get customer_orders_path(filtered: 1, statuses: CustomerOrder::STATUS_GROUPS['Open'] + ['Billed'])
    assert_equal %w[ST-1 ST-2 ST-4 ST-6], listed
    assert_select '#order-status-dropdown button', text: 'Open, Billed'

    get customer_orders_path(filtered: 1, quick: 'open')
    assert_equal %w[ST-1 ST-2 ST-6], listed, 'the "Open orders" view matches the Open group'
  end
end
