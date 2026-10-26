module Mrp
  # Time-phased MRP per warehouse: for every planned product (Mrp::Scope) at every warehouse that stocks
  # it or has supply / demand for it, projects stock day by day from firm supply and demand
  # (Mrp::Events), finds when it runs out and why, and suggests what to transfer, order or produce and
  # when (Mrp::ProductPlan, Mrp::Transfers). Parents are planned before components (Mrp::BomLevels) so
  # suggested production passes its component demand down, at the same warehouse.
  #
  # Supply / demand with no warehouse (PO, production order or order line without one) isn't netted
  # anywhere; it's listed under unassigned to be fixed. Safety stock is held at the product's main
  # warehouse (most stock, else site 0002).
  #
  # Lead times (days): purchase = product, else its primary vendor, else mrp_purchase_lead_days;
  # production = product, else mrp_production_days; transfers = mrp_transfer_days; customer orders
  # without a delivery date are dated order date + the customer's lead time, else mrp_customer_lead_days.
  class Plan
    MAIN_SITE = '0002'.freeze

    Result = Struct.new(:plans, :unassigned, :warehouses, :today, :horizon_end, keyword_init: true) do
      # Plans needing a transfer, an order or a production run, earliest action first.
      def actions(location_id = nil)
        plans.values.select(&:needs_action?).select { |p| location_id.nil? || p.location_id == location_id }
             .sort_by { |p| [p.first_action_date, p.product.name] }
      end

      def for_product(product_id) = plans.select { |(id, _), _| id == product_id }.values
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
      load_inputs
      @plans = {}
      @unassigned = []
      ordered.each { |product| plan_product(product) }
      Result.new(plans: @plans, unassigned: @unassigned, warehouses: @warehouses, today: @today,
                 horizon_end: @horizon_end)
    end

    private

    def load_inputs
      scope = Scope.new
      @products = scope.products
      @boms = scope.boms(@products.keys)
      @events = Events.new(@products.keys, today: @today, horizon_end: @horizon_end).load
      @stock = load_stock
      @warehouses = Location.where(id: warehouse_ids).index_by(&:id)
    end

    # Product ID → { location ID → quantity on hand there }.
    def load_stock
      LocationProduct.where(product_id: @products.keys).where.not(quantity: 0)
                     .pluck(:product_id, :location_id, :quantity).group_by(&:first)
                     .transform_values { |rows| rows.to_h { |_, location, qty| [location, qty.to_d] } }
    end

    def warehouse_ids
      (@stock.values.flat_map(&:keys) + @events.values.flatten.map(&:location_id)).compact.uniq
    end

    def ordered
      levels = BomLevels.new(@boms).call
      @products.values.sort_by { |product| [levels[product.id], product.id] }
    end

    def plan_product(product)
      by_location = events_by_warehouse(product)
      plans = warehouses_for(product, by_location).map { |id| new_plan(product, id, by_location[id] || []).net! }
      Transfers.new(plans, today: @today, transfer_days: transfer_days).apply!
      plans.each { |plan| record(plan) }
    end

    def transfer_days
      @transfer_days ||= AppSetting.mrp_days('mrp_transfer_days')
    end

    # The product's events by warehouse; those without one go to the unassigned list instead.
    def events_by_warehouse(product)
      by_location = @events[product.id].group_by(&:location_id)
      @unassigned.concat(Array(by_location.delete(nil)).map { |event| [product, event] })
      by_location
    end

    # Warehouses with supply / demand for the product or stock of it.
    def warehouses_for(product, by_location)
      (by_location.keys + Array(@stock[product.id]&.keys)).uniq
    end

    def new_plan(product, location_id, events)
      bom = @boms[product.id] || []
      setup = ProductPlan::Setup.new(bom: bom, lead_days: lead_days(product, bom),
                                     on_hand: @stock.dig(product.id, location_id) || 0,
                                     safety: location_id == home(product) ? product.safety_stock : 0,
                                     location: @warehouses[location_id])
      ProductPlan.new(product, events, setup, today: @today)
    end

    def lead_days(product, bom)
      bom.any? ? production_days(product) : purchase_lead_days(product)
    end

    def record(plan)
      @plans[[plan.product.id, plan.location_id]] = plan
      plan.component_demand.each { |component_id, event| @events[component_id] << event }
    end

    # The warehouse holding the product's safety stock: where most of it is, else the main warehouse.
    def home(product)
      @stock[product.id]&.max_by { |_, qty| qty }&.first || main_warehouse_id
    end

    def main_warehouse_id
      @main_warehouse_id ||= Location.find_by(pdi_site_code: MAIN_SITE)&.id
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
