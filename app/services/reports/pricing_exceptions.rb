module Reports
  class PricingExceptions < Base
    LABELS = { 'lock_mismatch' => 'Locked quote price', 'rule_mismatch' => 'Pricing rule',
               'no_price' => 'No price' }.freeze

    report title: 'Pricing exceptions', area: :sales,
           description: "Order lines priced differently from the customer's locked quote or pricing rule, " \
                        'for orders taken in the period.',
           filters: %i[dates customer_id product_id]

    def columns
      [column(:order_no, 'Order'), column(:order_date, 'Ordered', :date), column(:status, 'Status'),
       column(:customer, 'Customer'), column(:product, 'Product'), column(:check, 'Against'),
       column(:price, 'Price', :price), column(:expected, 'Expected', :price),
       column(:quantity, 'Quantity', :number, total: true), column(:difference, 'Difference', :currency, total: true)]
    end

    def rows
      @rows ||= scope.includes(customer_order: :customer).order('customer_orders.order_date')
                     .map { |line| line_row(line) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.customer_order_path(row[:order]) if column.key == :order_no
    end

    private

    def scope
      scope = CustomerOrderProduct.price_mismatches.joins(:customer_order)
                                  .where(customer_orders: { order_date: time_range })
      scope = scope.where(customer_orders: { customer_id: filters[:customer_id] }) if filters[:customer_id]
      filters[:product_id] ? scope.where(product_id: filters[:product_id]) : scope
    end

    def line_row(line)
      order_values(line.customer_order).merge(
        product: line.product_name, check: check_label(line), price: line.price, expected: line.expected_price,
        quantity: line.quantity, difference: difference(line)
      )
    end

    def check_label(line)
      LABELS[line.price_check] || line.price_check
    end

    def order_values(order)
      { order: order, order_no: order.external_order_no || "##{order.id}", order_date: order.order_date&.to_date,
        status: order.odor_status || order.order_status&.humanize, customer: order.customer&.name }
    end

    # (price − expected) × quantity; positive = charged more than expected.
    def difference(line)
      (line.price.to_d - line.expected_price.to_d) * line.quantity.to_d if line.price && line.expected_price
    end
  end
end
