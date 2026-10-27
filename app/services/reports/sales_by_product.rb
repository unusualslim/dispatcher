module Reports
  class SalesByProduct < Base
    include SalesLines

    report title: 'Sales by product', area: :sales,
           description: 'Quantity, average price and net sales per product for orders invoiced in the period.',
           filters: %i[dates item_type customer_id location_id]

    def columns
      sales_columns([column(:product_id, 'Product'), column(:name, 'Name'), column(:category, 'Category')])
        .insert(5, column(:average_price, 'Avg price', :price))
    end

    def rows
      @rows ||= begin
        sums = sales_by('customer_order_products.product_name')
        products = Product.where(id: sums.map(&:first)).index_by(&:id)
        sums.map { |code, *values| product_row(code, products[code], values) }.sort_by { |row| -row[:net] }
      end
    end

    private

    def product_row(code, product, values)
      orders, qty, net, tax = values
      { product_id: code, name: product&.name, category: product&.category, **sales_values(orders, qty, net, tax),
        average_price: (net / qty if qty.nonzero?) }
    end
  end
end
