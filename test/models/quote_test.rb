require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  fixtures :products, :product_components, :customers, :users

  setup do
    @customer = customers(:acme)
    @other    = customers(:river_transport)
    @user     = users(:admin_user)
    @product  = products(:def_finished)  # cost_per_unit 5.00
    @product.standard_cost_histories.create!(amount: 6.00, effective_date: Date.today - 30)

    # Dynamic rule: inventory cost + 10% = 5.50
    @rule = PricingRule.create!(name: 'DEF markup', pricing_basis: 'inventory_cost',
                                pricing_method: 'markup', value: 10)
    @rule.products << @product
  end

  def make_quote(price:, valid_from: Date.today, expiry_date: Date.today + 30, customer: @customer,
                 locks_pricing: true, rule: nil)
    Quote.create!(
      customer: customer, locks_pricing: locks_pricing, valid_from: valid_from, expiry_date: expiry_date,
      quote_products_attributes: [{ product_id: @product.id, quantity: 100, price: price, pricing_rule_id: rule&.id }]
    )
  end

  def lookup_price(customer = @customer, date: Date.today)
    PricingRuleService.lookup(customer, @product, date: date)&.dig(:price)
  end

  test "without a lock, the dynamic rule prices the order" do
    assert_equal BigDecimal("5.50"), lookup_price
  end

  test "an accepted quote locks its price for the customer" do
    make_quote(price: 4.75).accept!(@user)

    result = PricingRuleService.lookup(@customer, @product)
    assert_equal BigDecimal("4.75"), result[:price]
    assert_not_nil result[:quote_product]
    assert_equal BigDecimal("5.50"), lookup_price(@other), "other customers keep the rule price"
  end

  test "the lock holds even when costs change" do
    make_quote(price: 4.75).accept!(@user)
    @product.update_column(:cost_per_unit, 9.00)
    assert_equal BigDecimal("4.75"), lookup_price
  end

  test "lock only applies inside the validity window" do
    make_quote(price: 4.75, valid_from: Date.today + 5, expiry_date: Date.today + 10).accept!(@user)

    assert_equal BigDecimal("5.50"), lookup_price(date: Date.today)
    assert_equal BigDecimal("4.75"), lookup_price(date: Date.today + 5)
    assert_equal BigDecimal("4.75"), lookup_price(date: Date.today + 10)
    assert_equal BigDecimal("5.50"), lookup_price(date: Date.today + 11)
  end

  test "draft, sent, and rejected quotes don't lock" do
    quote = make_quote(price: 4.75)
    assert_equal BigDecimal("5.50"), lookup_price
    quote.update!(status: 'sent')
    assert_equal BigDecimal("5.50"), lookup_price
    quote.update!(status: 'rejected')
    assert_equal BigDecimal("5.50"), lookup_price
  end

  test "quotes that don't lock pricing (pre-existing quotes) never lock" do
    make_quote(price: 4.75, locks_pricing: false).accept!(@user)
    assert_equal BigDecimal("5.50"), lookup_price
  end

  test "a newer accepted quote replaces the old lock from its start date" do
    old_quote = make_quote(price: 4.75, valid_from: Date.today, expiry_date: Date.today + 60)
    old_quote.accept!(@user)
    new_quote = make_quote(price: 5.10, valid_from: Date.today + 10, expiry_date: Date.today + 40)
    new_quote.accept!(@user)

    old_line = old_quote.quote_products.first.reload
    assert_equal Date.today + 10, old_line.superseded_on
    assert_equal Date.today + 9,  old_line.locked_through

    assert_equal BigDecimal("4.75"), lookup_price(date: Date.today + 9)
    assert_equal BigDecimal("5.10"), lookup_price(date: Date.today + 10)
    assert_equal BigDecimal("5.50"), lookup_price(date: Date.today + 41), "rules resume after the new quote expires"
  end

  test "accepting doesn't touch another customer's locks" do
    other_quote = make_quote(price: 4.00, customer: @other)
    other_quote.accept!(@user)
    make_quote(price: 4.75).accept!(@user)

    assert_nil other_quote.quote_products.first.reload.superseded_on
    assert_equal BigDecimal("4.00"), lookup_price(@other)
  end

  test "line records a snapshot of how its price was reached" do
    line = make_quote(price: 5.50, rule: @rule).quote_products.first

    assert_equal @rule, line.pricing_rule
    assert_equal 'inventory_cost', line.pricing_basis
    assert_equal 'markup', line.pricing_method
    assert_equal BigDecimal("10"), line.rule_value
    assert_equal BigDecimal("5.00"), line.basis_cost
    assert_not line.price_overridden?
    assert_equal @product.name, line.product_name
  end

  test "a hand-edited price is flagged as overridden" do
    line = make_quote(price: 5.25, rule: @rule).quote_products.first
    assert line.price_overridden?
  end

  test "snapshot is frozen once the quote is accepted" do
    quote = make_quote(price: 5.50, rule: @rule)
    quote.accept!(@user)
    @product.update_column(:cost_per_unit, 9.00)

    line = quote.quote_products.first
    line.update!(quantity: 200)
    assert_equal BigDecimal("5.00"), line.reload.basis_cost
  end

  test "price-locking quote requires a validity window and a product on each line" do
    quote = Quote.new(customer: @customer, locks_pricing: true)
    assert_not quote.valid?
    assert quote.errors[:valid_from].any?
    assert quote.errors[:expiry_date].any?

    quote = Quote.new(customer: @customer, locks_pricing: true, valid_from: Date.today, expiry_date: Date.today - 1)
    assert_not quote.valid?
    assert quote.errors[:expiry_date].any?
  end

  test "build_order links order lines back to the quote" do
    quote = make_quote(price: 4.75)
    quote.accept!(@user)

    order = quote.build_order
    line  = order.customer_order_products.first
    assert_equal BigDecimal("4.75"), line.price
    assert_equal quote.quote_products.first, line.quote_product
  end
end
