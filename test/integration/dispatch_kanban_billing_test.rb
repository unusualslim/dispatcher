require 'test_helper'

# Orders released for billing or billed are done: they leave the dispatch board's unassigned list.
class DispatchKanbanBillingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    sign_in User.create!(email: 'admin-kanban@example.com', password: 'password123', role: 'admin')
  end

  def order(status, name)
    CustomerOrder.create!(location: Location.create!(company_name: name, location_category_id: 2),
                          order_status: status, required_delivery_date: Date.current)
  end

  test 'billing-stage orders leave the unassigned list; dispatch cards keep all their orders' do
    open = order('open_order', 'Kb Open Site')
    releasing = order('released_for_billing', 'Kb Releasing Site')
    billed = order('billed', 'Kb Billed Site')
    dispatch = Dispatch.create!(dispatch_date: Date.current, status: 'Sent to Driver')
    dispatch.customer_orders << order('released_for_billing', 'Kb Dispatched Site')

    get kanban_dispatches_path

    assert_select "a[href='#{customer_order_path(open)}']"
    assert_select "a[href='#{customer_order_path(releasing)}']", count: 0
    assert_select "a[href='#{customer_order_path(billed)}']", count: 0
    assert_select "a[href='#{dispatch_path(dispatch)}']", /Kb Dispatched Site/
  end
end
