# Resolves the best pricing rule for a customer + product on a given date,
# then calculates the sell price.
#
# Priority: fewest products in the rule wins (most specific).
# Among ties, most recent effective_date wins.
class PricingRuleService
  # Returns { price: BigDecimal, rule: PricingRule } or nil if no rule applies.
  def self.lookup(customer, product, date: Date.today)
    return nil unless product

    customer_id = customer.is_a?(Customer) ? customer.id : customer.to_i

    # Find rules that include this product, then load them with full associations
    # (avoids the join filter corrupting pricing_rule_products.size used for priority)
    matching_ids = PricingRuleProduct.where(product_id: product.id).pluck(:pricing_rule_id)
    return nil if matching_ids.empty?

    rules = PricingRule
      .where(id: matching_ids)
      .where('(customer_id = ? OR customer_id IS NULL)', customer_id)
      .includes(:pricing_rule_products, :products)

    active_rules = rules.select { |r| r.active?(date) }
    return nil if active_rules.empty?

    # Customer-specific rules beat global rules; within each group, fewest products wins.
    customer_rules = active_rules.select { |r| r.customer_id == customer_id }
    global_rules   = active_rules.select { |r| r.customer_id.nil? }

    best = pick_best(customer_rules) || pick_best(global_rules)
    return nil unless best

    price = best.calculated_price(product)
    return nil unless price

    { price: price, rule: best }
  end

  private

  def self.pick_best(rules)
    return nil if rules.empty?
    rules.min_by { |r| [r.pricing_rule_products.size, -(r.effective_date&.to_time&.to_i || 0)] }
  end
end
