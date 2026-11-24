module Planning
  # Purchasing → Planning Assumptions: the data gaps that make MRP, Suggested POs, Suggested Production and Min/Max
  # fall back on defaults or guesses, grouped so one fix clears many (a vendor lead time covers all its items).
  # Filling these in turns the planning numbers from assumptions into facts.
  class AssumptionReport
    VendorGap = Struct.new(:vendor, :products, keyword_init: true)
    CustomerGap = Struct.new(:customer, :orders, keyword_init: true)

    def initialize
      products = Mrp::Scope.new.products.values
      made_ids = ProductComponent.where(product_id: products.map(&:id)).distinct.pluck(:product_id).to_set
      @made, @bought = products.partition { |p| made_ids.include?(p.id) }
    end

    # Bought items on the default lead time, by primary vendor (nil = no vendor on the product).
    def default_lead_by_vendor
      @default_lead_by_vendor ||= @bought.select { |p| LeadTime.purchase(p).default? }.group_by(&:primary_vendor)
                                         .map { |vendor, items| vendor_gap(vendor, items) }
                                         .sort_by { |gap| [gap.vendor ? 0 : 1, -gap.products.size] }
    end

    def vendor_gap(vendor, items) = VendorGap.new(vendor: vendor, products: items.sort_by(&:id))

    def default_production
      @default_production ||= @made.select { |p| LeadTime.production(p).default? }.sort_by(&:id)
    end

    # Open customer orders with no delivery date (MRP dates them by lead time), by customer.
    def undated_orders
      @undated_orders ||= CustomerOrder.where(order_status: Mrp::Events::DEMAND_STATUSES, required_delivery_date: nil)
                                       .includes(:customer).group_by(&:customer)
                                       .map { |customer, orders| CustomerGap.new(customer: customer, orders: orders) }
                                       .sort_by { |gap| -gap.orders.size }
    end

    def no_standard
      @no_standard ||= (@made + @bought).reject { |p| p.standard_cost.to_d.positive? }.sort_by(&:id)
    end

    def total
      default_lead_by_vendor.sum { |g| g.products.size } + default_production.size +
        undated_orders.sum { |g| g.orders.size } + no_standard.size
    end
  end
end
