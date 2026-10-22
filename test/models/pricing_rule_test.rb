require "test_helper"

class PricingRuleTest < ActiveSupport::TestCase
  fixtures :products, :product_components

  setup do
    @concentrate = products(:def_concentrate) # cost_per_unit 2.50, BOM qty 0.325
    @urea        = products(:urea)            # cost_per_unit 1.20, BOM qty 2.0
    @def_product = products(:def_finished)    # cost_per_unit 5.00

    @concentrate.standard_cost_histories.create!(amount: 3.00, effective_date: Date.today - 30)
    @urea.standard_cost_histories.create!(amount: 1.50, effective_date: Date.today - 30)
    @def_product.standard_cost_histories.create!(amount: 6.00, effective_date: Date.today - 30)
  end

  def rule(basis, method: 'markup', value: 10)
    PricingRule.new(name: 'Test', pricing_basis: basis, pricing_method: method, value: value)
  end

  test "inventory_cost uses weighted average cost_per_unit" do
    assert_equal BigDecimal("5.50"), rule('inventory_cost').calculated_price(@def_product)
  end

  test "standard_cost uses the most recent effective standard cost" do
    @def_product.standard_cost_histories.create!(amount: 7.00, effective_date: Date.today - 5)
    assert_equal BigDecimal("7.70"), rule('standard_cost').calculated_price(@def_product.reload)
  end

  test "standard_cost ignores future-dated entries" do
    @def_product.standard_cost_histories.create!(amount: 9.00, effective_date: Date.today + 5)
    assert_equal BigDecimal("6.60"), rule('standard_cost').calculated_price(@def_product.reload)
  end

  test "standard_cost ignores back-dated entries older than the current one" do
    @def_product.standard_cost_histories.create!(amount: 4.00, effective_date: Date.today - 60)
    assert_equal BigDecimal("6.60"), rule('standard_cost').calculated_price(@def_product.reload)
  end

  test "standard_calculated sums component standard costs, not inventory costs" do
    # 0.325 × 3.00 + 2.0 × 1.50 = 3.975 → +10% = 4.3725
    assert_equal BigDecimal("3.975"), @def_product.bom_standard_cost
    assert_equal BigDecimal("4.3725"), rule('standard_calculated').calculated_price(@def_product)
  end

  test "standard_calculated uses each component's most recent standard cost" do
    @urea.standard_cost_histories.create!(amount: 2.00, effective_date: Date.today - 1)
    # 0.325 × 3.00 + 2.0 × 2.00 = 4.975
    assert_equal BigDecimal("4.975"), @def_product.reload.bom_standard_cost
  end

  test "standard_calculated returns no price when a component lacks a standard cost" do
    @urea.standard_cost_histories.destroy_all
    @urea.update_column(:standard_cost, nil)
    assert_nil @def_product.reload.bom_standard_cost
    assert_nil rule('standard_calculated').calculated_price(@def_product)
    assert_equal [@urea], @def_product.bom_components_missing_standard_cost
  end

  test "lookup reports missing BOM components for a standard_calculated rule" do
    @urea.standard_cost_histories.destroy_all
    @urea.update_column(:standard_cost, nil)
    pricing_rule = rule('standard_calculated')
    pricing_rule.save!
    pricing_rule.products << @def_product

    result = PricingRuleService.lookup(nil, @def_product.reload)
    assert_nil result[:price]
    assert_equal pricing_rule, result[:rule]
    assert_equal [@urea], result[:missing_components]
  end

  test "standard_calculated returns no price for a product without a BOM" do
    assert_nil rule('standard_calculated').calculated_price(@urea)
  end
end
