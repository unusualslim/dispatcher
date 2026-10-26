module Mrp
  # Time-phased MRP: for every planned product (Mrp::Scope), projects stock day by day from firm supply
  # and demand (Mrp::Events), finds when it runs out and why, and suggests what to order or produce and
  # when (Mrp::ProductPlan). Parents are planned before components (Mrp::BomLevels) so suggested
  # production passes its component demand down.
  #
  # Lead times (days): purchase = product, else its primary vendor, else mrp_purchase_lead_days;
  # production = product, else mrp_production_days; customer orders without a delivery date are dated
  # order date + the customer's lead time, else mrp_customer_lead_days (AppSetting).
  class Plan
    Result = Struct.new(:plans, :today, :horizon_end, keyword_init: true) do
      # Products needing an order or a production run, earliest action first.
      def actions = plans.values.select { |p| p.suggestions.any? }.sort_by { |p| [p.first_action_date, p.product.name] }
      def expedites = plans.values.select { |p| p.expedite.any? }

      def flagged(flag)
        plans.values.flat_map { |p| p.rows.map(&:event).select { |e| e.flags.include?(flag) }.map { |e| [p, e] } }
      end
    end

    def initialize(today: Date.current, horizon_days: 60)
      @today = today
      @horizon_end = today + horizon_days
    end

    def run
      scope = Scope.new
      products = scope.products
      boms = scope.boms(products.keys)
      events = Events.new(products.keys, today: @today, horizon_end: @horizon_end).load
      plans = ordered(products, boms).to_h { |product| [product.id, plan(product, boms, events)] }
      Result.new(plans: plans, today: @today, horizon_end: @horizon_end)
    end

    private

    def ordered(products, boms)
      levels = BomLevels.new(boms).call
      products.values.sort_by { |product| [levels[product.id], product.id] }
    end

    def plan(product, boms, events)
      bom = boms[product.id] || []
      lead_days = bom.any? ? production_days(product) : purchase_lead_days(product)
      plan = ProductPlan.new(product, events[product.id], bom: bom, lead_days: lead_days, today: @today).net!
      plan.component_demand.each { |component_id, event| events[component_id] << event }
      plan
    end

    def purchase_lead_days(product)
      product.lead_time_days || product.primary_vendor&.lead_time_days ||
        AppSetting.mrp_days('mrp_purchase_lead_days')
    end

    def production_days(product)
      product.production_days || AppSetting.mrp_days('mrp_production_days')
    end
  end
end
