require "test_helper"

class QuoteMarginReviewTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  fixtures :products, :product_components, :customers, :users

  setup do
    @customer = customers(:acme)
    @user     = users(:admin_user)
    @def      = products(:def_finished)     # BOM: 0.325 concentrate + 2.0 urea
    @conc     = products(:def_concentrate)
    @urea     = products(:urea)
    @quoted_on = Date.today - 10
  end

  # Quote created and accepted 10 days ago, priced from the given rule.
  def locked_quote(rule, price: nil)
    travel_to(@quoted_on.to_time + 9.hours) do
      quote = Quote.create!(customer: @customer, locks_pricing: true, valid_from: Date.today, expiry_date: Date.today + 60,
                            quote_products_attributes: [{ product_id: @def.id, quantity: 1000, pricing_rule_id: rule.id,
                                                          price: price || rule.calculated_price(@def) }])
      quote.accept!(@user)
      quote
    end
  end

  def rule(basis, method, value)
    r = PricingRule.create!(name: "#{basis} #{method}", pricing_basis: basis, pricing_method: method, value: value)
    r.products << @def
    r
  end

  def review(quote) = QuoteMarginReview.for_quote(quote.reload).first

  test "standard cost rise below the rule's target margin needs a re-price, with the dated change as the driver" do
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    quote = locked_quote(rule('standard_cost', 'margin', 20))      # price 4.00 / 0.8 = 5.00
    @def.standard_cost_histories.create!(amount: 4.40, effective_date: Date.today - 2, created_by: @user)

    line = review(quote)
    assert_equal BigDecimal('4.00'), line.cost_then
    assert_equal BigDecimal('4.40'), line.cost_now
    assert_equal BigDecimal('0.40'), line.cost_change
    assert_in_delta 10.0, line.cost_change_pct, 0.001
    assert_in_delta 12.0, line.margin_pct_now, 0.001             # (5.00 - 4.40) / 5.00
    assert_equal BigDecimal('20'), line.target_margin_pct
    assert_equal :reprice, line.status
    assert_equal BigDecimal('5.50'), line.rule_price_now          # 4.40 / 0.8
    assert_equal BigDecimal('400'), line.margin_erosion_total     # 0.40 × 1000

    assert_equal 1, line.drivers.size
    driver = line.drivers.first
    assert_equal Date.today - 2, driver.date
    assert_equal BigDecimal('0.40'), driver.impact
  end

  test "small cost rise that keeps margin above target is watch, not re-price" do
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    quote = locked_quote(rule('standard_cost', 'markup', 25))      # price 5.00, target GM 20%
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    quote.quote_products.first.update_column(:price, 5.20)         # negotiated above rule: GM 23%
    @def.standard_cost_histories.create!(amount: 4.10, effective_date: Date.today - 1)

    line = review(quote)
    assert_in_delta 20.0, line.target_margin_pct, 0.01
    assert_equal :watch, line.status
  end

  test "flat or falling cost is ok" do
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    quote = locked_quote(rule('standard_cost', 'margin', 20))
    @def.standard_cost_histories.create!(amount: 3.90, effective_date: Date.today - 1)
    assert_equal :ok, review(quote).status
  end

  test "BOM drivers name each component that moved and its effect per unit" do
    @conc.standard_cost_histories.create!(amount: 3.00, effective_date: @quoted_on - 30)
    @urea.standard_cost_histories.create!(amount: 0.50, effective_date: @quoted_on - 30)
    quote = locked_quote(rule('standard_calculated', 'margin', 30)) # cost 0.975 + 1.00 = 1.975
    @urea.standard_cost_histories.create!(amount: 0.60, effective_date: Date.today - 3)

    line = review(quote)
    assert_equal BigDecimal('1.975'), line.cost_then
    assert_equal BigDecimal('2.175'), line.cost_now
    assert_equal 1, line.drivers.size
    assert_match 'Urea', line.drivers.first.label
    assert_equal BigDecimal('0.20'), line.drivers.first.impact     # +0.10/lb × 2.0 lb
    assert_equal Date.today - 3, line.drivers.first.date
  end

  test "inventory cost changes are recorded and explain the movement" do
    travel_to(@quoted_on - 1) { @def.update!(cost_per_unit: 4.00) }
    quote = locked_quote(rule('inventory_cost', 'markup', 10))     # price 4.40
    travel_to(Date.today - 4) { @def.update!(cost_per_unit: 4.30) }

    history = @def.inventory_cost_histories.reload.first           # most recent
    assert_equal BigDecimal('4.00'), history.previous_amount
    assert_equal BigDecimal('4.30'), history.amount

    line = review(quote)
    assert_equal BigDecimal('0.30'), line.cost_change
    assert_equal [BigDecimal('0.30')], line.drivers.map(&:impact)
    assert_equal :reprice, line.status                              # GM 2.3% vs 9.1% target
  end

  test "inventory cost as of a past date uses recorded history" do
    @def.update!(cost_per_unit: 4.00)
    travel_to(Date.today - 5) { @def.update!(cost_per_unit: 4.20) }
    travel_to(Date.today - 2) { @def.update!(cost_per_unit: 4.50) }

    assert_equal BigDecimal('4.00'), QuoteMarginReview.inventory_cost_on(@def.reload, Date.today - 20)
    assert_equal BigDecimal('4.20'), QuoteMarginReview.inventory_cost_on(@def, Date.today - 3)
    assert_equal BigDecimal('4.50'), QuoteMarginReview.inventory_cost_on(@def, Date.today)
  end

  test "unexplained part of a cost change is shown as 'other'" do
    @def.update_column(:cost_per_unit, 4.00)                        # no history recorded
    quote = locked_quote(rule('inventory_cost', 'markup', 10))
    @def.update_column(:cost_per_unit, 4.25)

    line = review(quote)
    assert_equal 1, line.drivers.size
    assert_match 'no dated history', line.drivers.first.label
    assert_equal BigDecimal('0.25'), line.drivers.first.impact
  end

  test "open_locks lists active and scheduled locks, worst first" do
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    ok_quote = locked_quote(rule('standard_cost', 'margin', 10), price: 6.00)
    @customer = customers(:river_transport)                         # separate customer, so no supersede
    bad_quote = locked_quote(rule('standard_cost', 'margin', 20))
    @def.standard_cost_histories.create!(amount: 4.40, effective_date: Date.today - 1)
    bad_quote.end_lock!(@user, on: Date.today + 5)

    lines = QuoteMarginReview.open_locks
    assert_equal [bad_quote, ok_quote], lines.map(&:quote)
    assert_equal %i[reprice watch], lines.map(&:status)

    ok_quote.end_lock!(@user, on: Date.today)
    assert_equal [bad_quote], QuoteMarginReview.open_locks.map(&:quote)
  end

  test "re-quote creates a draft at today's rule prices that replaces the lock when accepted" do
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    old_quote = locked_quote(rule('standard_cost', 'margin', 20))
    @def.standard_cost_histories.create!(amount: 4.40, effective_date: Date.today - 2)

    old_quote.reload
    new_quote = old_quote.create_requote!(QuoteMarginReview.for_quote(old_quote))
    assert new_quote.draft?
    assert_equal Date.today, new_quote.valid_from
    assert_equal Date.today + 60, new_quote.expiry_date
    line = new_quote.quote_products.first
    assert_equal BigDecimal('5.50'), line.price
    assert_not line.price_overridden?
    assert_match "Re-quote of #{old_quote.quote_number}", new_quote.notes
    assert_match '+0.4000 (+10.0%)', new_quote.notes

    new_quote.accept!(@user)
    assert_equal BigDecimal('5.50'), PricingRuleService.lookup(@customer, @def)[:price]
    assert_equal Date.today, old_quote.quote_products.first.reload.superseded_on
  end

  test "a price negotiated below target isn't flagged until cost rises" do
    @def.standard_cost_histories.create!(amount: 4.00, effective_date: @quoted_on - 30)
    quote = locked_quote(rule('standard_cost', 'margin', 20), price: 4.80)   # GM 16.7% vs 20% target

    line = review(quote)
    assert_in_delta 16.67, line.margin_floor_pct, 0.01
    assert_equal :ok, line.status

    @def.standard_cost_histories.create!(amount: 4.10, effective_date: Date.today - 1)
    assert_equal :reprice, review(quote).status
  end

  test "the first inventory cost recorded isn't a driver, and same-day changes after pricing are" do
    @def.update_column(:cost_per_unit, nil)
    travel_to(@quoted_on.to_time + 8.hours) { @def.update!(cost_per_unit: 4.00) }   # first cost: blank -> 4.00
    quote = locked_quote(rule('inventory_cost', 'markup', 10))                       # priced 9:00
    travel_to(@quoted_on.to_time + 15.hours) { @def.update!(cost_per_unit: 4.20) }  # same day, after pricing

    line = review(quote)
    assert_equal [BigDecimal('0.20')], line.drivers.map(&:impact)
    assert_equal @quoted_on, line.drivers.first.date
  end
end
