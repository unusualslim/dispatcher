# Suggested safety stock, min (reorder point) and max for the products MRP plans (Mrp::Scope), from the last
# 12 months' usage and an inventory turns target: 8 turns a year, 12 for high movers (class A: the items that
# make up the first 80% of usage value at standard cost). Usage = shipped sales + components used by completed
# production.
#
#   daily usage  = 12 months' usage / 365
#   safety stock = daily usage x lead days x safety %            (cover for a late delivery or a busy week)
#   min          = safety stock + daily usage x lead days         (order when stock + on order falls to this)
#   order qty    = 2 x (annual usage / target turns - safety)     (so average stock, safety + half an order,
#                                                                  turns the target number of times)
#   max          = min + order qty                                (order up to this, counting what's on order)
#
# The order is never less than a week's usage; when the lead time is too long for the target, that floor wins and
# the row says so. Lead days: production days for items with a BOM, else the product / vendor / default purchase
# lead time, as MRP uses. Suggestions only: nothing changes until someone applies them.
class MinMaxPlanner # rubocop:disable Metrics/ClassLength -- levels plus the assumptions behind them
  HISTORY_DAYS = 365
  A_SHARE = 0.8
  MIN_ORDER_DAYS = 7
  SETTINGS = { 'min_max_turns' => 8, 'min_max_turns_high' => 12, 'min_max_safety_pct' => 50 }.freeze
  NO_STANDARD = Planning::Assumption.new(:no_standard, 'No standard cost',
                                         'Without a standard cost the item is never ranked a high mover (12 turns).')

  Row = Struct.new(:product, :abc, :usage, :daily, :lead_days, :turns, :on_hand, :safety, :min_qty, :max_qty,
                   :turns_now, :note, :assumptions, keyword_init: true) do
    def current = [product.safety_stock, product.reorder_point, product.max_stock]
    def suggested = [safety, min_qty, max_qty]

    def apply!
      product.update!(safety_stock: safety, reorder_point: min_qty, max_stock: max_qty)
    end

    def changed?
      return false unless safety

      current.zip(suggested).any? { |now, new| now.to_d.round != new.to_d }
    end
  end

  def self.setting(key) = (AppSetting.get(key).presence || SETTINGS.fetch(key)).to_d

  def initialize(today: Date.current)
    @today = today
  end

  def rows
    @rows ||= begin
      products = Mrp::Scope.new.products.values
      classes = abc(products)
      products.sort_by { |p| [-usage_value(p), p.id] }.map { |product| row(product, classes[product.id]) }
    end
  end

  # Applies the suggestions for the given product IDs; returns how many were applied.
  def apply!(product_ids)
    picks = rows.select { |r| product_ids.include?(r.product.id) && r.safety }
    Product.transaction { picks.each(&:apply!) }
    picks.size
  end

  private

  def usage_value(product) = usage.fetch(product.id, 0).to_d * product.standard_cost.to_d

  def row(product, abc)
    base = basics(product, abc)
    annual = base[:usage]
    return Row.new(**base, note: 'No usage in 12 months') unless annual.positive?

    Row.new(**base, turns_now: turns_now(annual, base[:on_hand]), **levels(annual, base[:lead_days], base[:turns]))
  end

  def basics(product, abc)
    lead = Planning::LeadTime.for(product, made: bom_parents.include?(product.id))
    { product: product, abc: abc, usage: usage.fetch(product.id, 0).to_d, lead_days: lead.days,
      turns: self.class.setting(abc == 'A' ? 'min_max_turns_high' : 'min_max_turns'),
      on_hand: on_hand.fetch(product.id, 0).to_d, assumptions: assumptions(product, lead) }
  end

  # What the suggestion rests on that isn't recorded: a default lead time, less than a year of history (usage looks
  # low), or no standard cost (the item can't be ranked as a high mover).
  def assumptions(product, lead)
    [lead.assumption(made: bom_parents.include?(product.id)), history_assumption(product),
     (NO_STANDARD unless product.standard_cost.to_d.positive?)].compact
  end

  def history_assumption(product)
    first = first_used[product.id]
    return unless first && first > since

    months = ((@today - first) / 30).floor
    span = months.zero? ? 'under a month' : "#{months} month#{'s' unless months == 1}"
    Planning::Assumption.new(:short_history, "Only #{span} of history",
                             'Usage counts a full year; an item first used recently looks slower than it is.')
  end

  # When each product was first sold or used in production, any time.
  def first_used
    @first_used ||= first_sold.merge(first_produced_use) { |_, a, b| [a, b].compact.min }
                              .transform_values { |d| d&.to_date }
  end

  def first_sold
    CustomerOrderProduct.joins(:customer_order)
                        .where(customer_orders: { order_status: InventorySales::SHIPPED_STATUSES })
                        .group(:product_id).minimum(Arel.sql(Reports::ItemActivity::SOLD_ON))
  end

  def first_produced_use
    ProductionOrderComponent.joins(:production_order).where(production_orders: { status: 'completed' })
                            .where.not(product_id: nil).group(:product_id).minimum('production_orders.date_completed')
  end

  def turns_now(annual, stock) = ((annual / stock).round(1) if stock.positive?)

  def levels(annual, lead, turns)
    daily = annual / HISTORY_DAYS
    safety = safety_stock(daily, lead)
    order = 2 * ((annual / turns) - safety)
    floor = daily * MIN_ORDER_DAYS
    min = (safety + (daily * lead)).ceil
    { daily: daily, safety: safety, min_qty: min, max_qty: (min + [order, floor].max).ceil,
      note: (short_lead_note(turns) if order < floor) }
  end

  def safety_stock(daily, lead) = (daily * lead * self.class.setting('min_max_safety_pct') / 100).ceil

  def short_lead_note(turns) = "Lead time too long for #{turns.to_i} turns: a week's usage per order"

  # A = the products making up the first 80% of 12 months' usage value at standard cost.
  def abc(products)
    values = products.to_h { |p| [p.id, usage_value(p)] }
    cutoff = values.values.sum * A_SHARE
    running = 0.to_d
    values.sort_by { |_, v| -v }.to_h do |id, value|
      klass = 'A' if running < cutoff
      running += value
      [id, (klass || 'B/C' if value.positive?)]
    end
  end

  def usage
    @usage ||= sales.merge(production_use) { |_, a, b| a + b }
  end

  def since = @today - HISTORY_DAYS

  def sales
    CustomerOrderProduct.joins(:customer_order)
                        .where(customer_orders: { order_status: InventorySales::SHIPPED_STATUSES })
                        .where(Arel.sql("#{Reports::ItemActivity::SOLD_ON} >= ?"), since)
                        .group(:product_id).sum(Arel.sql(FinancialDashboard::Sales::QTY))
                        .transform_values(&:to_d)
  end

  def production_use
    ProductionOrderComponent.joins(:production_order)
                            .where(production_orders: { status: 'completed', date_completed: since.. })
                            .where.not(product_id: nil).group(:product_id)
                            .sum(Arel.sql('COALESCE(production_order_components.quantity_actual, ' \
                                          'production_order_components.quantity)'))
                            .transform_values(&:to_d)
  end

  def on_hand
    @on_hand ||= LocationProduct.group(:product_id).sum(:quantity)
  end

  def bom_parents = @bom_parents ||= ProductComponent.distinct.pluck(:product_id).to_set
end
