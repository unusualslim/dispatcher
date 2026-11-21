require 'test_helper'

# Sales → Customer Orders: the table with filters, sort on every column, remembered filters and the card view.
class CustomerOrderListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @admin = User.create!(email: 'order-list-admin@example.com', password: 'password123', role: 'admin')
    @acme = Customer.create!(name: 'Acme Fuel')
    @zed = Customer.create!(name: 'Zed Farms')
    @site = Location.create!(company_name: 'Acme Albany', city: 'Albany', location_category_id: 2)
    @plant = Location.create!(company_name: 'Plant 0002', city: 'Americus', location_category_id: 2,
                              show_in_warehouse_dropdown: true)
    @def = Product.create!(id: 'OL-901', name: 'Bulk DEF', category: 'DEF')
    @hose = Product.create!(id: 'OL-HOSE', name: 'Hose', category: 'Parts')

    @open = make_order(@acme, 'OD-100', 'Open Order', [@def, 500, 3.5], delivery: Date.current + 2, salesperson: 'Ann',
                                                                        carrier: 'FPL', ship_from: @plant)
    @billed = make_order(@zed, 'OD-200', 'Billed', [@hose, 2, 40], delivery: Date.current - 20, invoice: 'INV-9',
                                                                   invoice_date: Date.current - 15)
    @app_order = make_order(@acme, nil, 'Open Order', [@hose, 1, 40], delivery: Date.current - 3, po: 'PO-55')
  end

  EXTRA_FIELDS = { delivery: :required_delivery_date, invoice: :invoice_no, po: :customer_po_number,
                   ship_from: :ship_from_location }.freeze

  def make_order(customer, number, status, (product, qty, price), **extra)
    fields = extra.transform_keys { |key| EXTRA_FIELDS.fetch(key, key) }
    CustomerOrder.create!(customer: customer, location: @site, external_order_no: number, order_status: status,
                          **fields).tap do |o|
      o.customer_order_products.create!(product: product, quantity: qty, price: price)
    end
  end

  def listed
    css_select('table.order-list-table tbody tr td[data-col="order"] a').map(&:text)
  end

  test 'the table is the default view and every column sorts' do
    sign_in @admin

    get customer_orders_path(filtered: 1)
    assert_response :success
    assert_select 'table.order-list-table'
    assert_select 'th[data-col="total"]'
    assert_select 'td[data-col="ship_from"]', text: 'Plant 0002'
    assert_select 'td[data-col="total"]', text: '$1,750.00'

    CustomerOrderListQuery::SORTS.each_key do |column|
      %w[asc desc].each do |direction|
        get customer_orders_path(filtered: 1, sort: "#{column}_#{direction}")
        assert_response :success, "sort #{column}_#{direction}"
        assert_equal 3, listed.size, "sort #{column}_#{direction}"
      end
    end

    get customer_orders_path(filtered: 1, sort: 'customer_desc')
    assert_equal 'OD-200', listed.first
    get customer_orders_path(filtered: 1, sort: 'qty_desc')
    assert_equal %W[OD-100 OD-200 ##{@app_order.id}], listed
  end

  test 'filters narrow the list' do
    sign_in @admin
    {
      { search: 'INV-9' } => ['OD-200'],
      { search: 'PO-55' } => ["##{@app_order.id}"],
      { quick: 'open' } => ['OD-100', "##{@app_order.id}"],
      { quick: 'overdue' } => ["##{@app_order.id}"],
      { statuses: ['Billed'] } => ['OD-200'],
      { customer_id: @zed.id } => ['OD-200'],
      { ship_from_id: @plant.id } => ['OD-100'],
      { product_id: @def.id } => ['OD-100'],
      { category: 'Parts' } => ['OD-200', "##{@app_order.id}"],
      { date_field: 'invoice', from: (Date.current - 16).iso8601 } => ['OD-200'],
      { date_field: 'delivery', to: (Date.current - 10).iso8601 } => ['OD-200'],
      { salesperson: 'Ann' } => ['OD-100'],
      { carrier: 'FPL' } => ['OD-100'],
      { source: 'app' } => ["##{@app_order.id}"],
      { dispatch: 'unassigned', quick: 'open' } => ['OD-100', "##{@app_order.id}"]
    }.each do |filters, expected|
      get customer_orders_path(filters.merge(filtered: 1, sort: 'order_asc'))
      assert_response :success, filters.inspect
      assert_equal expected.sort, listed.sort, filters.inspect
    end
  end

  test 'filters are remembered; old dashboard and dispatch links still land on the right list' do
    sign_in @admin

    get customer_orders_path(filtered: 1, customer_id: @zed.id)
    get customer_orders_path
    assert_redirected_to customer_orders_path(customer_id: @zed.id, filtered: 1)
    get customer_orders_path(reset: 1)
    get customer_orders_path
    assert_response :success

    get customer_orders_path(status_preset: 'active')
    assert_redirected_to customer_orders_path(quick: 'open', filtered: 1)
    get customer_orders_path(order_status: 'On Hold')
    assert_redirected_to customer_orders_path(quick: 'on_hold', filtered: 1)
  end

  test 'totals are hidden without the customer pricing flag; the card view still works' do
    sign_in staff_user('order-list-sales@example.com', { 'sales' => 'view' }, flags: [])

    get customer_orders_path(filtered: 1, sort: 'total_desc')
    assert_response :success
    assert_select 'th[data-col="total"]', count: 0
    assert_select 'input#price_check', count: 0

    get customer_orders_path(filtered: 1, view: 'card')
    assert_response :success
    assert_select 'table.order-list-table', count: 0
    assert_select '.card-title', text: /Acme Albany/
  end
end
