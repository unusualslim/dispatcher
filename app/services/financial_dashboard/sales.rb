class FinancialDashboard
  # Billed sales for one period: order lines on orders invoiced in the range (by invoice date), at PDI's
  # price × shipped quantity (ordered when PDI didn't say). Taxes are PDI's per-unit estimate; when the
  # price includes them they're taken out of the product figure.
  class Sales
    CANCELLED = ['Cancelled as Order', 'Cancelled as Quote', 'Expired', 'Expired Quote', 'Quote'].freeze
    QTY = 'COALESCE(customer_order_products.shipped_quantity, customer_order_products.quantity)'.freeze
    AMOUNT = "#{QTY} * COALESCE(customer_order_products.price, 0)".freeze
    TAX = "#{QTY} * COALESCE(customer_order_products.tax_per_unit, 0)".freeze
    NET = "#{AMOUNT} - CASE WHEN customer_order_products.price_includes_taxes THEN #{TAX} ELSE 0 END".freeze
    TYPES = { 'fuel' => 'Fuel', 'warehouse' => 'Warehouse', 'non_inventory' => 'Freight & non-inventory',
              nil => 'Uncategorized' }.freeze

    attr_reader :range

    def initialize(range)
      @range = range
    end

    def orders
      CustomerOrder.where(invoice_date: range).where.not(order_status: CANCELLED)
    end

    def lines
      CustomerOrderProduct.joins(:customer_order).merge(orders).left_joins(product: :reporting_group)
    end

    # { item type => [net sales, quantity] } for fuel / warehouse / non_inventory / nil (no product or group).
    def by_type
      @by_type ||= lines.group('reporting_groups.item_type')
                        .pluck(Arel.sql('reporting_groups.item_type'), Arel.sql("SUM(#{NET})"), Arel.sql("SUM(#{QTY})"))
                        .to_h { |type, net, qty| [type, [net.to_d, qty.to_d]] }
    end

    def net_sales
      by_type.values.sum(0.to_d) { |net, _| net }
    end

    def taxes
      @taxes ||= lines.sum(Arel.sql(TAX)).to_d
    end

    def total
      net_sales + taxes
    end

    def gallons
      by_type.dig('fuel', 1) || 0.to_d
    end

    def order_count
      @order_count ||= orders.count
    end

    def average_order
      net_sales / order_count if order_count.positive?
    end

    # Cost of what was sold (sale movements at inventory cost); nil before costed tracking covered the period.
    def cost_of_sales
      start = InventoryRevaluation.start_date
      return unless start && start <= range.begin

      sales = InventoryTransaction.where(movement_type: 'sale', occurred_on: range)
      -sales.sum(Arel.sql(InventoryValuation::SIGNED_VALUE))
    end

    def gross_margin
      cost = cost_of_sales
      net_sales - cost if cost
    end

    # [[Customer, net sales]] largest first.
    def top_customers(limit = 5)
      totals = lines.group('customer_orders.customer_id').order(Arel.sql("SUM(#{NET}) DESC")).limit(limit)
                    .pluck('customer_orders.customer_id', Arel.sql("SUM(#{NET})"))
      customers = Customer.where(id: totals.map(&:first)).index_by(&:id)
      totals.map { |id, net| [customers[id], net.to_d] }
    end

    # Customers whose first invoiced order falls in the period.
    def new_customers
      CustomerOrder.where.not(invoice_date: nil).where.not(customer_id: nil).group(:customer_id)
                   .having('MIN(invoice_date) BETWEEN ? AND ?', range.begin, range.end).count.size
    end
  end
end
