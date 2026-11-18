module Reports
  # Standard against actual for completed production orders: yield (produced vs planned), component usage at
  # standard cost (actual vs BOM), and labor hours and cost (/line actual vs standard).
  class ProductionVariance < Base
    report title: 'Production variance and yield', area: :production, flag: :costs,
           description: 'Completed production orders: yield, material usage and labor against standard.',
           filters: %i[dates location_id category product_id]

    def columns
      [column(:order, 'Production order'), column(:completed, 'Completed', :date), column(:product, 'Product'),
       column(:planned, 'Planned qty', :decimal, total: true), column(:produced, 'Produced', :decimal, total: true),
       column(:yield, 'Yield', :percent), column(:material_standard, 'Material at standard', :currency, total: true),
       column(:material_actual, 'Material used at standard', :currency, total: true),
       column(:material_variance, 'Material variance', :currency, total: true),
       column(:labor_hours_standard, 'Std labor hrs', :decimal, total: true),
       column(:labor_hours_actual, 'Actual labor hrs', :decimal, total: true),
       column(:labor_variance, 'Labor variance', :currency, total: true)]
    end

    def rows
      @rows ||= orders.map { |order| row(order) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.production_order_path(row[:order_id]) if column.key == :order
    end

    private

    def orders
      scope = ProductionOrder.where(status: 'completed', date_completed: time_range)
                             .includes(:product, production_order_components: :product, jobs: { job_workers: :user })
                             .order(:date_completed)
      scope = scope.where(location_id: filters[:location_id]) if filters[:location_id]
      scope = scope.where(product_id: filters[:product_id]) if filters[:product_id]
      scope = scope.joins(:product).where(products: { category: filters[:category] }) if filters[:category]
      scope.to_a
    end

    def row(order)
      costing = ProductionOrderCosting.new(order)
      planned = order.qty_to_make.to_d
      produced = costing.qty_produced
      standard, actual = material(order)
      { order_id: order.id, order: order.number, completed: order.date_completed&.to_date,
        product: order.product&.name || order.item, planned: planned, produced: produced,
        yield: (produced / planned if planned.positive?), material_standard: standard, material_actual: actual,
        material_variance: standard - actual, labor_hours_standard: costing.standard_labor_hours,
        labor_hours_actual: costing.actual_labor_hours,
        labor_variance: costing.standard_labor_cost - costing.actual_labor_cost }
    end

    # Planned and actual component quantities, both at the component's standard cost (positive variance = used less).
    def material(order)
      order.production_order_components.select(&:product).reduce([0.to_d, 0.to_d]) do |(standard, actual), c|
        cost = c.product.current_standard_cost.to_d
        [standard + (c.quantity.to_d * cost), actual + ((c.quantity_actual || c.quantity).to_d * cost)]
      end
    end
  end
end
