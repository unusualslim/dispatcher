# Bulk price increase (Sales → Pricing Rules → Bulk increase): raises the pricing rules that price a set of products
# (every product whose BOM uses a component, a product group, or both) by a percent, or flat rules by a dollar amount.
# A markup or margin rule is moved so its prices rise by that percent at any cost: markup m → (1 + m)(1 + x) − 1,
# margin m → 1 − (1 − m) / (1 + x). A dollar increase applies to flat rules only; the others are listed as skipped.
# Locked quotes on those products then show "Price increase" on Quote Margin Review, to re-quote in bulk.
class PricingRuleIncrease
  Change = Struct.new(:rule, :old_value, :new_value, :products, :other_products, :skip, keyword_init: true)

  attr_reader :component_id, :category, :percent, :amount

  def initialize(component_id: nil, category: nil, percent: nil, amount: nil)
    @component_id = component_id.presence
    @category = category.presence
    @percent = percent.presence && BigDecimal(percent.to_s)
    @amount = amount.presence && BigDecimal(amount.to_s)
  end

  def valid?
    (component_id || category).present? && exactly_one_increase?
  end

  def exactly_one_increase?
    [percent, amount].compact.one?(&:positive?) && [percent, amount].compact.size == 1
  end

  # Products the increase is for.
  def products
    @products ||= begin
      scope = Product.all
      scope = scope.where(id: ProductComponent.where(component_product_id: component_id).select(:product_id)) if
        component_id
      scope = scope.where(category: category) if category
      scope.order(:id).to_a
    end
  end

  def changes
    @changes ||= rules.map { |rule| change_for(rule) }
  end

  def apply!
    PricingRule.transaction do
      changes.reject(&:skip).each { |change| change.rule.update!(value: change.new_value) }
    end
  end

  private

  def rules
    PricingRule.joins(:pricing_rule_products).where(pricing_rule_products: { product_id: products.map(&:id) })
               .includes(:customer, :products).distinct.order(:name)
  end

  def change_for(rule)
    ids = products.map(&:id)
    covered, others = rule.products.partition { |p| ids.include?(p.id) }
    new_value, skip = new_value(rule)
    Change.new(rule: rule, old_value: rule.value.to_d, new_value: new_value, products: covered,
               other_products: others, skip: skip)
  end

  # [new value, reason skipped]
  def new_value(rule)
    value = rule.value.to_d
    return [flat_value(value).round(4), nil] if rule.pricing_method == 'flat'
    return [nil, 'A dollar increase applies to flat rules only'] unless percent

    [percent_rule_value(rule.pricing_method, value / 100, percent / 100).round(4), nil]
  end

  # The markup or margin (in percent) whose prices are (1 + x) times today's.
  def percent_rule_value(method, current, increase)
    raised = method == 'markup' ? ((1 + current) * (1 + increase)) - 1 : 1 - ((1 - current) / (1 + increase))
    raised * 100
  end

  def flat_value(value)
    percent ? value * (1 + (percent / 100)) : value + amount
  end
end
