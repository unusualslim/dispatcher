module Reports
  # Shared by the sales reports: the Financial Dashboard's sales lines (orders invoiced in the range) with
  # the report's filters, summed per group.
  module SalesLines
    S = FinancialDashboard::Sales
    SUMS = ['COUNT(DISTINCT customer_orders.id)', "SUM(#{S::QTY})", "SUM(#{S::NET})", "SUM(#{S::TAX})"].freeze

    private

    # Filter → condition on the sales lines.
    CONDITIONS = {
      item_type: ->(value) { { reporting_groups: { item_type: value } } },
      product_id: ->(value) { { product_id: value } },
      customer_id: ->(value) { { customer_orders: { customer_id: value } } },
      location_id: ->(value) { { location_id: value } }
    }.freeze

    def sales_lines
      CONDITIONS.reduce(S.new(range).lines) do |lines, (key, condition)|
        filters[key] ? lines.where(condition.call(filters[key])) : lines
      end
    end

    # [[group value, orders, quantity, net, taxes]] for the given GROUP BY expression.
    def sales_by(group_sql)
      sales_lines.group(Arel.sql(group_sql)).pluck(Arel.sql(group_sql), *SUMS.map { |sql| Arel.sql(sql) })
                 .map { |group, orders, qty, net, tax| [group, orders, qty.to_d, net.to_d, tax.to_d] }
    end

    def sales_columns(first)
      [*first, column(:orders, 'Orders', :number, total: true), column(:quantity, 'Quantity', :number, total: true),
       column(:net, 'Net sales', :currency, total: true), column(:taxes, 'Taxes (est.)', :currency, total: true),
       column(:total, 'Total billed', :currency, total: true)]
    end

    def sales_values(orders, qty, net, tax)
      { orders: orders, quantity: qty, net: net, taxes: tax, total: net + tax }
    end
  end
end
