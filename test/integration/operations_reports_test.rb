require 'test_helper'

# The reports built from the operations group's requirements list (open orders, contracts, item activity, classes,
# trends, ABC, purchase history, production shortages and variance).
class OperationsReportsTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  include Devise::Test::IntegrationHelpers

  fixtures :products, :locations, :location_categories

  setup do
    @warehouse = locations(:warehouse)
    @made = products(:def_finished)
    @urea = products(:urea)
    @made.update!(category: 'DEF')
    LocationProduct.create!(location: @warehouse, product: @made, quantity: 30)
    @customer = Customer.create!(name: 'Acme', preferred_contact_method: 'no preference')
    sign_in User.create!(email: "ops-reports-#{SecureRandom.hex(3)}@example.com", password: 'password123',
                         role: 'admin')
  end

  def open_order(number, quantity, status: 'open_order', requested: Date.current + 2)
    order = CustomerOrder.create!(external_order_no: number, order_status: status, customer: @customer,
                                  location: locations(:terminal), order_date: Date.current - 5,
                                  required_delivery_date: requested, salesperson: 'Mike Flynn')
    order.customer_order_products.create!(product: @made, product_name: @made.id, quantity: quantity, price: 10,
                                          location: @warehouse)
    order
  end

  test 'open order report hands stock out first come first served and slices by disposition' do
    open_order('OD-1', 20, requested: Date.current - 3)
    open_order('OD-2', 25)
    open_order('OD-3', 5, status: 'picking_in_progress', requested: Date.current + 9)

    rows = Reports::OpenOrderLines.new({}).rows.index_by { |r| r[:order] }
    assert_equal(['Picking / staged', 'Ready to ship'], rows.values_at('OD-3', 'OD-1').pluck(:disposition))
    assert_equal 3, rows['OD-1'][:days_late]
    assert_equal [5, 20], [rows['OD-2'][:available], rows['OD-2'][:short]].map(&:to_i)
    assert_includes ['Needs production', 'Backorder (purchase)'], rows['OD-2'][:disposition]

    get report_path('open_order_lines', view: 'late')
    assert_response :success
    assert_select 'tbody tr', 1
    assert_select 'th.report-sort', minimum: 10
  end

  test 'contract prices show standard and current cost margins' do
    @made.update!(standard_cost: 6, cost_per_unit: 8)
    quote = Quote.create!(customer: @customer, status: 'accepted', locks_pricing: true, valid_from: Date.current - 1,
                          expiry_date: Date.current + 30, accepted_at: Time.current)
    quote.quote_products.create!(product: @made, quantity: 1, price: 10)

    row = Reports::ContractPrices.new({}).rows.first
    assert_equal [0.4, 0.2], [row[:standard_margin], row[:current_margin]].map(&:to_f)
    get report_path('contract_prices')
    assert_response :success
  end

  test 'item activity, sales by class, trend, ABC and purchase history render with data' do
    sold = CustomerOrder.create!(external_order_no: 'OD-9', order_status: 'billed', customer: @customer,
                                 location: locations(:terminal), order_date: Date.current - 10,
                                 invoice_date: Date.current - 9)
    sold.customer_order_products.create!(product: @made, product_name: @made.id, quantity: 4, price: 25)
    vendor = Vendor.create!(id: 'OR-V', name: 'Urea Co')
    po = PurchaseOrder.create!(vendor: vendor, location: @warehouse, status: 'received', received_at: 2.days.ago)
    po.line_items.create!(product: @urea, quantity: 100, unit_cost: 0.5)

    activity = Reports::ItemActivity.new({}).rows.index_by { |r| r[:product_id] }
    assert_equal Date.current - 9, activity[@made.id][:last_sold]
    assert_equal 2.days.ago.to_date, activity[@urea.id][:last_received]
    assert_equal [30, 675], [activity[@made.id][:on_hand].to_i, activity[@made.id][:days_on_hand]]
    assert_equal 'DEF', Reports::SalesByClass.new({}).rows.first[:group]
    assert_equal 'New', Reports::CustomerSalesTrend.new({}).rows.first[:flag]
    assert_equal 'A', Reports::AbcClasses.new({}).rows.first[:abc]
    assert_equal 50, Reports::PoHistoryByItem.new({}).rows.first[:amount].to_i

    %w[item_activity sales_by_class customer_sales_trend abc_classes po_history_by_item].each do |key|
      get report_path(key)
      assert_response :success, key
    end
    get report_path('customer_sales_trend', view: 'customer_product')
    assert_select 'th', text: /Description/
  end

  test 'production shortages and variance' do
    open_order_po = ProductionOrder.create!(number: 'PO-S1', product: @made, location: @warehouse, status: 'created',
                                            due_date: Date.current + 1, qty_to_make: 100)
    open_order_po.production_order_components.create!(product: @urea, quantity: 40, description: 'Urea')
    LocationProduct.create!(location: @warehouse, product: @urea, quantity: 15)

    short = Reports::ProductionShortages.new({}).rows.first
    assert_equal [40, 15, 25], [short[:needed], short[:available], short[:short]].map(&:to_i)

    @urea.update!(standard_cost: 2)
    done = ProductionOrder.create!(number: 'PO-V1', product: @made, location: @warehouse, status: 'completed',
                                   date_completed: Time.current, qty_to_make: 100, total_qty_produced: 95,
                                   lot_number: 'FPS-X-1')
    done.production_order_components.create!(product: @urea, quantity: 40, quantity_actual: 42, description: 'Urea')
    row = Reports::ProductionVariance.new({}).rows.first
    assert_equal [0.95, -4], [row[:yield].to_f, row[:material_variance].to_i]

    %w[production_shortages production_variance].each do |key|
      get report_path(key)
      assert_response :success, key
    end
  end

  test 'order line margins flag lines below zero or below their rule target; the order shows margin after freight' do
    @made.update!(standard_cost: 9)
    rule = PricingRule.create!(name: 'DEF 25%', pricing_basis: 'standard_cost', pricing_method: 'margin', value: 25)
    order = open_order('OD-M', 10)
    order.customer_order_products.first.update!(pricing_rule: rule)
    order.order_freight_charges.create!(side: 'sale', charge_type: 'freight', basis: 'flat', amount: 30)
    order.order_freight_charges.create!(side: 'purchase', charge_type: 'freight', basis: 'flat', amount: 50)

    row = Reports::OrderMargins.new({}).rows.first
    assert_equal ['Below rule target', 0.1, 0.25], [row[:flag], row[:margin].to_f, row[:target].to_f]

    margin = OrderMargin.new(order)
    assert_equal [100, 90, -10], [margin.sales, margin.product_cost, margin.margin].map(&:to_i)
    get customer_order_path(order)
    assert_select '.card-header', text: 'Margin after freight'

    quote = Quote.create!(customer: @customer, status: 'draft')
    quote.quote_products.create!(product: @made, price: 12)
    get quote_path(quote)
    assert_select 'th', text: 'Cost today (margin)'
    assert_select 'td div', text: /Standard \$9.0000 \(25.0%\)/
  end

  test 'orders and POs show their shipping weight from product lb per unit' do
    @made.update!(weight: 9.5)
    order = open_order('OD-W', 10)
    get customer_order_path(order)
    assert_select 'td', text: '95 lb'

    po = PurchaseOrder.create!(vendor: Vendor.create!(id: 'OR-W', name: 'Jug Co'), status: 'draft')
    po.line_items.create!(product: @made, quantity: 4, unit_cost: 1)
    po.line_items.create!(product: @urea, quantity: 1, unit_cost: 1)
    assert_equal [38, 1], [po.total_weight_lbs.to_i, po.unweighed_lines]
    get print_purchase_order_path(po)
    assert_select 'td', text: '38 lb'
  end
end
