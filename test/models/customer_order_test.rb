require 'test_helper'

class CustomerOrderTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @site = Location.create!(company_name: 'COT Site', location_category_id: 2)
    @customer = Customer.create!(name: 'COT Customer')
    @def = Product.create!(id: 'COT-DEF', name: 'COT DEF')
    @oil = Product.create!(id: 'COT-OIL', name: 'COT Oil', hazmat: true)
  end

  def order(**attrs)
    CustomerOrder.create!(location: @site, customer: @customer, order_status: 'open_order', **attrs)
  end

  test 'statuses store the PDI status names' do
    o = order(order_status: :truck_loaded)

    assert_equal 'Loaded', o.read_attribute_before_type_cast(:order_status)
    assert o.truck_loaded?
  end

  test 'line quantities total into the approximate product amount' do
    o = order(customer_order_products_attributes: [{ product_id: @def.id, quantity: 300 },
                                                   { product_id: @oil.id, quantity: 55 }])

    assert_in_delta 355, o.reload.approximate_product_amount
  end

  test 'saving remembers the customer delivers to that location, once' do
    order
    order

    assert_equal 1, CustomerLocation.where(customer: @customer, location: @site).count
  end

  test 'unassigned open orders are active orders only' do
    open = order
    billed = order(order_status: :billed)
    ids = CustomerOrder.unassigned_open_orders.ids

    assert_includes ids, open.id
    assert_not_includes ids, billed.id
  end

  test 'dispatchable: app orders and PDI orders on our own trucks' do
    app_order = order
    ours = order(external_order_no: 'COT-1', pdi_carrier_id: '1514')
    legacy = order(external_order_no: 'COT-2', carrier: 'Five Points Service, Inc.')
    other = order(external_order_no: 'COT-3', pdi_carrier_id: '9999')
    ids = CustomerOrder.dispatchable.ids

    assert_includes ids, app_order.id
    assert_includes ids, ours.id
    assert_includes ids, legacy.id
    assert_not_includes ids, other.id
  end

  test 'hazmat products come from the lines, without repeats' do
    o = order(customer_order_products_attributes: [{ product_id: @oil.id, quantity: 1 },
                                                   { product_id: @oil.id, quantity: 2 },
                                                   { product_id: @def.id, quantity: 3 }])

    assert_equal [@oil], o.reload.hazmat_products
  end
end
