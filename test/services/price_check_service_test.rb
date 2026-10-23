require 'test_helper'

class PriceCheckServiceTest < ActiveSupport::TestCase
  fixtures :products, :customers, :users, :locations, :location_categories

  setup do
    @customer = customers(:acme)
    @user     = users(:admin_user)
    @product  = products(:def_finished) # cost_per_unit 5.00
    @rule = PricingRule.create!(name: 'DEF +10%', pricing_basis: 'inventory_cost', pricing_method: 'markup', value: 10)
    @rule.products << @product # rule price 5.50
  end

  def imported_order(price:, order_date: Time.current, status: 'Open Order', external: 'PDI-1')
    order = CustomerOrder.create!(customer: @customer, location: locations(:terminal), order_status: status,
                                  order_date: order_date, external_order_no: external)
    order.customer_order_products.create!(product: @product, product_name: @product.id, quantity: 100, price: price)
    order
  end

  def lock_at(price, valid_from: Date.today - 5)
    quote = Quote.create!(customer: @customer, locks_pricing: true, valid_from: valid_from, expiry_date: Date.today + 30,
                          quote_products_attributes: [{ product_id: @product.id, quantity: 1, price: price }])
    quote.accept!(@user)
    quote
  end

  def checked_line(order)
    PriceCheckService.check_order!(order)
    order.customer_order_products.first.reload
  end

  test 'matching the rule price' do
    line = checked_line(imported_order(price: 5.50))
    assert_equal 'match', line.price_check
    assert_equal BigDecimal('5.50'), line.expected_price
    assert_equal @rule, line.pricing_rule
  end

  test 'differences under the tolerance count as a match' do
    assert_equal 'match', checked_line(imported_order(price: 5.5009)).price_check
    assert_equal 'rule_mismatch', checked_line(imported_order(price: 5.502, external: 'PDI-2')).price_check
  end

  test 'PDI price that differs from the rule is a rule mismatch' do
    line = checked_line(imported_order(price: 5.25))
    assert_equal 'rule_mismatch', line.price_check
    assert_equal BigDecimal('-0.25'), line.price_variance
  end

  test 'PDI price that differs from an active quote lock is a lock mismatch' do
    quote = lock_at(4.75)
    line = checked_line(imported_order(price: 5.50))
    assert_equal 'lock_mismatch', line.price_check
    assert_equal BigDecimal('4.75'), line.expected_price
    assert_equal quote.quote_products.first, line.quote_product
    assert line.price_mismatch?
  end

  test 'lock is evaluated on the order date, not today' do
    lock_at(4.75, valid_from: Date.today)
    line = checked_line(imported_order(price: 5.50, order_date: 3.days.ago))
    assert_equal 'match', line.price_check, 'order placed before the lock started is priced by the rule'
  end

  test 'no expected price when nothing applies' do
    order = imported_order(price: 1.00)
    order.customer_order_products.first.update!(product: products(:urea))
    assert_equal 'no_price', checked_line(order).price_check
  end

  test "editing a checked line's price re-checks it" do
    lock_at(4.75)
    line = checked_line(imported_order(price: 5.50))
    assert_equal 'lock_mismatch', line.price_check

    line.update!(price: 4.75)
    assert_equal 'match', line.reload.price_check
  end

  test 'import runs the price check on synced lines' do
    lock_at(4.75)
    order = CustomerOrder.create!(customer: @customer, location: locations(:terminal), order_status: 'Open Order',
                                  external_order_no: 'PDI-9')
    CustomerOrderImportService.new(nil).send(:sync_line_items, order,
                                             [{ product_code: @product.id, ordered_qty: 100, unit_price: BigDecimal('5.10') }])

    line = order.customer_order_products.reload.first
    assert_equal 'lock_mismatch', line.price_check
    assert_equal BigDecimal('4.75'), line.expected_price
  end

  test 'recheck covers open imported orders only' do
    open_imported = imported_order(price: 5.25)
    billed        = imported_order(price: 5.25, status: 'Billed', external: 'PDI-2')
    manual        = imported_order(price: 5.25, external: nil)

    assert_equal 1, PriceCheckService.recheck_open_orders!
    assert_equal 'rule_mismatch', open_imported.customer_order_products.first.reload.price_check
    assert_nil billed.customer_order_products.first.reload.price_check
    assert_nil manual.customer_order_products.first.reload.price_check
  end
end
