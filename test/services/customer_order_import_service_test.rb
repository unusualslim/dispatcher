require 'test_helper'

class CustomerOrderImportServiceTest < ActiveSupport::TestCase
  fixtures :locations, :location_categories

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  def import(orders)
    service = CustomerOrderImportService.new('unused.xls')
    service.define_singleton_method(:parse_orders) { orders }
    service.run
  end

  def order_data(**attrs)
    { external_order_no: 'OD-1', customer_name: 'Acme', order_date: Date.new(2026, 10, 1), odor_status: 'Billed',
      invoice_no: 'INV-9', invoice_date: Date.new(2026, 10, 3), salesperson: 'Pat', location_name: 'Acme Site',
      line_items: [{ product_code: 'X1', ordered_qty: 5, unit_price: 2 }] }.merge(attrs)
  end

  test 'an order already in the app only gets its invoice details' do
    order = CustomerOrder.create!(external_order_no: 'OD-1', order_status: 'dispatched', location: locations(:terminal))
    order.customer_order_products.create!(product_name: 'API', quantity: 7, price: 3)

    result = import([order_data])

    assert_equal [0, 1], [result.created, result.updated]
    order.reload
    assert_equal ['dispatched', Date.new(2026, 10, 3), 'INV-9', 'Pat'],
                 [order.order_status, order.invoice_date, order.invoice_no, order.salesperson]
    assert_equal ['API'], order.customer_order_products.pluck(:product_name)
    assert_equal 1, import([order_data]).skipped
  end

  test 'orders not in the app are created with their lines' do
    assert_equal 1, import([order_data(external_order_no: 'OD-2')]).created
    assert_equal ['X1'], CustomerOrder.find_by!(external_order_no: 'OD-2').customer_order_products.pluck(:product_name)
  end
end
