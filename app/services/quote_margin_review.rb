# Compares locked quote prices (fixed) with today's costs and rule prices
# (dynamic), so sales can re-price a customer or ask purchasing why costs rose.
#
# For each locked quote line: cost when quoted vs cost today on the same basis
# its rule used, margin then vs now, the rule's target margin, today's rule
# price, and the dated cost changes ("drivers") that explain the movement.
class QuoteMarginReview
  BASIS_LABELS = { 'standard_cost' => 'Standard cost', 'inventory_cost' => 'Inventory cost',
                   'standard_calculated' => 'BOM standard cost' }.freeze

  # Margin points a line may fall below its floor before it's flagged Re-price
  # (it shows as Watch until then).
  REPRICE_ALLOWANCE_PCT = BigDecimal('1')

  Driver = Struct.new(:label, :date, :from, :to, :impact, keyword_init: true)

  Line = Struct.new(:quote_product, :basis, :since, :priced_time, :cost_then, :cost_now, :target_margin_pct,
                    :rule_price_now, :drivers, keyword_init: true) do
    delegate :quote, :product, :price, :quantity, to: :quote_product

    def cost_change     = (cost_now - cost_then if cost_now && cost_then)
    def cost_change_pct = (cost_change / cost_then * 100 if cost_change && cost_then.positive?)
    def margin_then     = (price - cost_then if price && cost_then)
    def margin_now      = (price - cost_now if price && cost_now)
    def margin_pct_then = (margin_then / price * 100 if margin_then && price.positive?)
    def margin_pct_now  = (margin_now / price * 100 if margin_now && price.positive?)
    # Margin lost per unit, and across the quoted volume.
    def margin_erosion       = (margin_then - margin_now if margin_then && margin_now)
    def margin_erosion_total = (margin_erosion * quantity if margin_erosion && quantity)
    def price_gap            = (rule_price_now - price if rule_price_now && price)

    # The margin floor: the rule's target, or the margin actually quoted if the
    # price was deliberately set below target (so a negotiated discount isn't
    # flagged until rising cost eats into it further).
    def margin_floor_pct
      return target_margin_pct unless target_margin_pct && margin_pct_then
      # Prices are rounded to 4 decimals, so a rule-priced line can sit a hair
      # under its target; only a real discount lowers the floor.
      quoted_below_target? ? margin_pct_then : target_margin_pct
    end

    def quoted_below_target?
      target_margin_pct && margin_pct_then && margin_pct_then < target_margin_pct - BigDecimal('0.05')
    end

    # :reprice — margin more than REPRICE_ALLOWANCE_PCT points below the floor (or negative)
    # :watch   — cost has risen but margin is still within the allowance
    # :ok      — cost flat or down
    # :unknown — no cost to compare against
    def status
      return :unknown if margin_pct_now.nil?
      return :reprice if margin_now.negative?
      return :reprice if margin_floor_pct && margin_pct_now < margin_floor_pct - REPRICE_ALLOWANCE_PCT
      return :watch   if cost_change && cost_change > BigDecimal('0.00005')
      :ok
    end
  end

  STATUS_ORDER = { reprice: 0, watch: 1, unknown: 2, ok: 3 }.freeze

  # Lines on accepted quotes whose lock is active or scheduled, worst first.
  def self.open_locks(customer_id: nil)
    scope = QuoteProduct.joins(:quote).merge(Quote.accepted_locks)
                        .where('quotes.expiry_date >= ?', Date.today)
                        .includes(:pricing_rule, product: [:standard_cost_histories, :inventory_cost_histories,
                                                           { product_components: { component_product: :standard_cost_histories } }],
                                  quote: :customer)
    scope = scope.where(quotes: { customer_id: customer_id }) if customer_id.present?
    lines = scope.select { |qp| qp.product && %i[active scheduled].include?(qp.lock_status) }.map { |qp| review(qp) }
    lines.sort_by { |l| [STATUS_ORDER[l.status], -(l.margin_erosion || 0)] }
  end

  def self.for_quote(quote)
    quote.quote_products.select(&:product).map { |qp| review(qp) }
  end

  def self.review(qp)
    product = qp.product
    basis   = qp.pricing_basis || 'standard_cost'
    priced  = qp.priced_at || qp.quote.accepted_at || qp.created_at
    since   = priced.to_date

    cost_then = qp.basis_cost || cost_on(basis, product, priced)
    cost_now  = cost_on(basis, product, Time.current)

    line = Line.new(
      quote_product:     qp,
      basis:             basis,
      since:             since,
      priced_time:       priced,
      cost_then:         cost_then&.to_d,
      cost_now:          cost_now&.to_d,
      target_margin_pct: target_margin_pct(qp),
      rule_price_now:    PricingRuleService.rule_lookup(qp.quote.customer_id, product)&.dig(:price),
    )
    line.drivers = drivers_for(line)
    line
  end

  # Cost of a product on the given basis as of a time. Standard costs are
  # dated (effective_date); inventory cost history is timestamped.
  def self.cost_on(basis, product, time)
    case basis
    when 'standard_cost'       then product.current_standard_cost(time.to_date)
    when 'standard_calculated' then product.bom_standard_cost(time.to_date)
    when 'inventory_cost'      then inventory_cost_on(product, time)
    end
  end

  # Inventory cost has history only from when tracking started; before the
  # first recorded change, the cost was that change's previous amount.
  # Accepts a Date (end of that day) or a Time.
  def self.inventory_cost_on(product, at)
    at = at.end_of_day if at.is_a?(Date)
    return product.cost_per_unit if at >= Time.current
    history = product.inventory_cost_histories.sort_by(&:created_at)
    last_before = history.select { |h| h.created_at <= at }.last
    return last_before.amount if last_before
    first_after = history.first
    first_after ? first_after.previous_amount : product.cost_per_unit
  end

  # The gross margin % the line's rule aims for (nil for flat/manual pricing).
  def self.target_margin_pct(qp)
    value = qp.rule_value&.to_d
    return nil unless value
    case qp.pricing_method
    when 'margin' then value
    when 'markup' then (value / (100 + value) * 100).round(2)
    end
  end

  def self.drivers_for(line)
    product = line.product
    drivers =
      case line.basis
      when 'standard_cost'       then standard_cost_drivers(product, line.since)
      when 'inventory_cost'      then inventory_cost_drivers(product, line.priced_time)
      when 'standard_calculated' then bom_drivers(product, line.since)
      else []
      end

    # Anything the dated changes don't account for (BOM edits, costs entered
    # before history was tracked, etc.) is shown rather than hidden.
    if line.cost_change
      residual = line.cost_change - drivers.sum { |d| d.impact.to_d }
      if residual.abs >= BigDecimal('0.0001')
        label = line.basis == 'inventory_cost' && product.inventory_cost_histories.empty? ?
                  'Inventory cost change (no dated history before tracking started)' :
                  'Other change (e.g. BOM edited, or cost recorded without history)'
        drivers << Driver.new(label: label, impact: residual)
      end
    end
    drivers
  end

  def self.standard_cost_drivers(product, since)
    entries = product.standard_cost_histories.select { |h| h.effective_date > since && h.effective_date <= Date.today }
                     .sort_by { |h| [h.effective_date, h.created_at] }
    previous = product.current_standard_cost(since)
    entries.map do |h|
      d = Driver.new(label: "Standard cost changed#{" (#{h.notes})" if h.notes.present?}", date: h.effective_date,
                     from: previous, to: h.amount, impact: (h.amount - previous.to_d if previous))
      previous = h.amount
      d
    end
  end

  # Changes after the line was priced. The first cost ever recorded (no
  # previous amount) isn't a change, so it's skipped.
  def self.inventory_cost_drivers(product, priced_time)
    product.inventory_cost_histories.select { |h| h.created_at > priced_time && h.previous_amount }
           .sort_by(&:created_at).map do |h|
      Driver.new(label: 'Inventory cost updated', date: h.created_at.to_date, from: h.previous_amount, to: h.amount,
                 impact: (h.amount.to_d - h.previous_amount.to_d if h.amount && h.previous_amount))
    end
  end

  # Which BOM components moved, and what each did to the cost per unit.
  def self.bom_drivers(product, since)
    product.product_components.filter_map do |pc|
      component = pc.component_product
      next unless component
      from = component.current_standard_cost(since)
      to   = component.current_standard_cost(Date.today)
      next if from.nil? || to.nil? || from == to
      qty = pc.quantity_per_unit.to_d
      Driver.new(label: "#{component.name} (#{number(qty)} #{pc.uom.presence || 'per unit'})",
                 date: component.standard_cost_histories.find { |h| h.effective_date > since && h.effective_date <= Date.today }&.effective_date,
                 from: from, to: to, impact: (to.to_d - from.to_d) * qty)
    end
  end

  def self.number(n) = n.to_s('F').sub(/\.0+\z/, '')
end
