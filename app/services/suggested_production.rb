# Production → Suggested Production: the production runs MRP says are needed (Mrp::Plan's planned production for
# products with a BOM, at each warehouse), with the start date (need date - production days) and the open orders
# behind each. A planner ticks runs, adjusts quantity or start date, and creates production orders (status
# Created, BOM components filled in). Created orders are firm supply in MRP, so their suggestions drop off.
class SuggestedProduction
  Run = Struct.new(:product, :location, :quantity, :start_on, :need_date, :causes, :assumptions,
                   keyword_init: true) do
    def late?(today = Date.current) = start_on < today
  end

  def initialize(today: Date.current, horizon_days: 60)
    @today = today
    @horizon_days = horizon_days
  end

  def runs
    @runs ||= plan.plans.values.select(&:manufactured?).flat_map { |product_plan| runs_for(product_plan) }
                  .sort_by { |r| [r.start_on, r.product.name] }
  end

  # picks: [{ product_id:, location_id:, quantity:, start_on:, need_date: }] → production orders.
  def self.create_orders!(picks)
    products = Product.where(id: picks.pluck(:product_id)).index_by(&:id)
    picks.select { |p| products[p[:product_id]] && p[:location_id].present? && p[:quantity].to_d.positive? }
         .map { |pick| create_order!(products[pick[:product_id]], pick) }
  end

  def self.create_order!(product, pick)
    ProductionOrder.transaction do
      order = ProductionOrder.create!(product: product, item: product.name, qty_to_make: pick[:quantity].to_d,
                                      location_id: pick[:location_id], status: 'created',
                                      production_date: [safe_date(pick[:start_on]), Date.current].compact.max,
                                      due_date: safe_date(pick[:need_date]),
                                      notes: 'Created from Suggested Production (MRP).')
      order.build_components_from_bom!
      order.save!
      order
    end
  end

  def self.safe_date(value)
    Date.parse(value.to_s) if value.present?
  rescue Date::Error
    nil
  end

  private

  def runs_for(product_plan)
    causes = product_plan.causes
    assumptions = product_plan.assumptions
    product_plan.suggestions.select(&:production?).map do |s|
      Run.new(product: product_plan.product, location: product_plan.location, quantity: s.qty.ceil,
              start_on: s.act_by, need_date: s.need_date, causes: causes, assumptions: assumptions)
    end
  end

  def plan
    @plan ||= Mrp::Plan.new(today: @today, horizon_days: @horizon_days).run
  end
end
