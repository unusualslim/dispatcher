module Reports
  # Margin on each order line: price against the item's standard cost (its BOM cost when it has no standard), with
  # lines flagged when they lose money or fall below their pricing rule's target margin (a markup rule's target is
  # turned into the margin it gives). Lines with no rule are only flagged when negative.
  class OrderMargins < Base
    CANCELLED = %w[cancelled_as_order cancelled_as_quote expired expired_quote quote].freeze

    report title: 'Order line margins', area: :sales, flag: :costs,
           description: 'Every order line in the period with cost and margin, flagging lines below zero or below ' \
                        'their pricing rule\'s target margin.',
           filters: %i[dates customer_id product_id category only_problems]

    def columns
      [column(:order, 'Order'), column(:order_date, 'Ordered', :date), column(:customer, 'Customer'),
       column(:product_id, 'Item'), column(:description, 'Description'), column(:quantity, 'Qty', :decimal),
       column(:price, 'Price', :price), column(:cost, 'Std cost', :price),
       column(:margin_amount, 'Margin $', :currency, total: true), column(:margin, 'Margin %', :percent),
       column(:target, 'Rule target', :percent), column(:flag, 'Flag')]
    end

    def rows
      @rows ||= begin
        all = lines.filter_map { |line| row(line) }
        filters.only_problems? ? all.select { |r| r[:flag] } : all
      end
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.customer_order_path(row[:order_id]) if column.key == :order
    end

    private

    def lines
      scope = CustomerOrderProduct.joins(:customer_order)
                                  .where(customer_orders: { order_date: range })
                                  .where.not(customer_orders: { order_status: CANCELLED })
                                  .where.not(product_id: nil).where('customer_order_products.quantity > 0')
                                  .includes(:pricing_rule, customer_order: :customer, product: :standard_cost_histories)
      scope = scope.where(customer_orders: { customer_id: filters[:customer_id] }) if filters[:customer_id]
      scope = scope.where(product_id: filters[:product_id]) if filters[:product_id]
      scope = scope.joins(:product).where(products: { category: filters[:category] }) if filters[:category]
      scope.to_a
    end

    def row(line)
      price = line.price.to_d
      cost = line.product.current_standard_cost&.to_d || line.product.bom_standard_cost
      return unless cost && price.positive?

      margin = (price - cost) / price
      target = target_margin(line.pricing_rule)
      order = line.customer_order
      { order_id: order.id, order: order.external_order_no.presence || "##{order.id}", order_date: order.order_date,
        customer: order.customer&.name, product_id: line.product_id, description: line.product.name,
        quantity: line.quantity.to_d, price: price, cost: cost, margin_amount: (price - cost) * line.quantity.to_d,
        margin: margin, target: target, flag: flag(margin, target) }
    end

    # The rule's target as a margin share: a margin rule's value, or the margin a markup gives.
    def target_margin(rule)
      return unless rule

      value = rule.value.to_d
      case rule.pricing_method
      when 'margin' then value / 100
      when 'markup' then value / (100 + value) if value > -100
      end
    end

    def flag(margin, target)
      return 'Negative' if margin.negative?

      'Below rule target' if target && margin < target - 0.0001
    end
  end
end
