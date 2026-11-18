module Reports
  # Sales subtotalled by product group (Coolants, Oils, DEF…), the "sales report by class".
  class SalesByClass < Base
    include SalesLines

    report title: 'Sales by class', area: :sales, flag: :financial_dashboard,
           description: 'Net sales per product group for orders invoiced in the period, with each group\'s share.',
           filters: %i[dates item_type customer_id location_id]

    def columns
      sales_columns([column(:group, 'Group'), column(:products, 'Items sold', :number)])
        .push(column(:share, 'Share', :percent))
    end

    def rows
      @rows ||= begin
        sums = sales_by('products.category')
        items = sales_lines.group(Arel.sql('products.category')).distinct.count(:product_id)
        total = sums.sum { |row| row[3] }
        sums.map { |group, *values| class_row(group, items[group], values, total) }.sort_by { |row| -row[:net] }
      end
    end

    private

    def class_row(group, items, values, total)
      orders, qty, net, tax = values
      { group: group || '(no group)', products: items.to_i, **sales_values(orders, qty, net, tax),
        share: (net / total if total.nonzero?) }
    end
  end
end
