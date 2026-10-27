module Reports
  class SalesByMonth < Base
    include SalesLines

    report title: 'Sales by month', area: :sales,
           description: 'Monthly net sales, taxes and volume for orders invoiced in the period.',
           filters: %i[dates item_type customer_id product_id location_id]

    def self.default_from(today)
      today.beginning_of_month << 12
    end

    def columns
      sales_columns([column(:month, 'Month')]) + [column(:gallons, 'Fuel gallons', :number, total: true)]
    end

    def rows
      @rows ||= begin
        gallons = fuel_gallons
        sales_by("to_char(customer_orders.invoice_date, 'YYYY-MM')").sort_by(&:first).map do |month, *values|
          { month: Date.strptime(month, '%Y-%m').strftime('%b %Y'), **sales_values(*values),
            gallons: gallons[month] || 0 }
        end
      end
    end

    private

    def fuel_gallons
      sales_lines.where(reporting_groups: { item_type: 'fuel' })
                 .group(Arel.sql("to_char(customer_orders.invoice_date, 'YYYY-MM')"))
                 .sum(Arel.sql(FinancialDashboard::Sales::QTY))
    end
  end
end
