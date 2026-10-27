class FinancialDashboard
  # Delivery, production, quality, pricing and purchasing for one period.
  class Operations
    attr_reader :range

    def initialize(range)
      @range = range
    end

    # Order taken → invoiced, in days, for orders invoiced in the period.
    def average_delivery_days
      dated.average(Arel.sql('invoice_date - CAST(order_date AS date)'))&.to_d
    end

    # Share of invoiced orders billed on or before their required delivery date.
    def on_time_share
      scope = dated.where.not(required_delivery_date: nil)
      total = scope.count
      scope.where('invoice_date <= required_delivery_date').count.to_d / total if total.positive?
    end

    def completed_orders
      ProductionOrder.where(status: 'completed', date_completed: range)
    end

    def quantity_produced
      completed_orders.sum(:total_qty_produced).to_d
    end

    # Earned standard labor hours ÷ actual /line hours, averaged over completed orders that have both.
    def labor_efficiency
      values = completed_orders.includes(:product, jobs: { job_workers: :user })
                               .filter_map { |order| ProductionOrderCosting.new(order).labor_efficiency }
      values.sum / values.size if values.any?
    end

    def quality_issues
      QualityResult.out_of_range.where(tested_at: range.begin.beginning_of_day..range.end.end_of_day).count
    end

    # Order lines priced differently from the customer's lock or rule, on orders taken in the period.
    def price_exceptions
      CustomerOrderProduct.price_mismatches.joins(:customer_order)
                          .where(customer_orders: { order_date: range.begin.beginning_of_day..range.end.end_of_day })
                          .count
    end

    # Receipt cost above standard (positive = paid more).
    def purchase_price_variance
      InventoryTransaction.where(movement_type: 'receipt', occurred_on: range).sum(:variance_amount).to_d
    end

    # Value of purchase orders received in the period.
    def po_spend
      PurchaseOrderLineItem.joins(:purchase_order).where(purchase_orders: { voided_at: nil })
                           .where(purchase_orders: { received_at: range.begin.beginning_of_day..range.end.end_of_day })
                           .sum('purchase_order_line_items.quantity * purchase_order_line_items.unit_cost').to_d
    end

    private

    def dated
      CustomerOrder.where(invoice_date: range).where.not(order_date: nil)
                   .where.not(order_status: FinancialDashboard::Sales::CANCELLED)
    end
  end
end
