require 'test_helper'

module PdiOrders
  class LinkedOrderMergeTest < ActiveSupport::TestCase
    setup do
      LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
      @yard = Location.create!(company_name: 'Link Yard', location_category_id: 2)
      @customer = Customer.create!(name: 'South GA Tools (test)', preferred_contact_method: 'no preference')
    end

    test 'merges an app order linked by PDI order number in its notes into the synced PDI order' do
      app_order = CustomerOrder.create!(customer: @customer, location: @yard, order_status: 'open_order',
                                        notes: 'OD-051224-26')
      app_order.customer_order_products.create!(product_name: 'BF0130', quantity: 5)
      pdi_order = CustomerOrder.create!(customer: @customer, location: @yard, order_status: 'shipped',
                                        external_order_no: 'OD-051224-26', notes: 'PO 4471')
      dispatch = Dispatch.create!(dispatch_date: Date.current)
      DispatchCustomerOrder.create!(dispatch: dispatch, customer_order: app_order)
      quote = Quote.create!(customer: @customer, status: 'accepted', customer_order: app_order)
      unlinked = CustomerOrder.create!(customer: @customer, location: @yard, order_status: 'open_order',
                                       notes: 'OD-999999-26 not synced yet')

      result = LinkedOrderMerge.new.run

      assert_equal ["#{app_order.id} → OD-051224-26"], result.merged
      assert_not CustomerOrder.exists?(app_order.id)
      assert_equal [pdi_order.id], dispatch.reload.customer_orders.ids
      assert_equal pdi_order.id, quote.reload.customer_order_id
      assert_equal "PO 4471\nFrom app order ##{app_order.id}: OD-051224-26", pdi_order.reload.notes
      assert CustomerOrder.exists?(unlinked.id), 'its PDI order has not synced yet'
    end
  end
end
