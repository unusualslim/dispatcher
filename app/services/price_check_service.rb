# Compares the price on imported (PDI) order lines with the price the customer
# should get: their locked quote price on the order date, or else the best
# pricing rule price. PDI's price is never changed — mismatches are flagged so
# they can be corrected in PDI before invoicing.
class PriceCheckService
  # Differences smaller than this count as a match (PDI may round to 3 decimals).
  TOLERANCE = BigDecimal('0.001')

  # Orders whose prices can still be corrected before or at billing.
  OPEN_STATUSES = (CustomerOrder::ACTIVE_STATUSES + ['Shipped', 'Delivered', 'Accepted by Site', 'Quarantine']).freeze

  def self.check_order!(order)
    date = (order.order_date || order.created_at || Time.current).to_date
    order.customer_order_products.includes(:product).each { |line| check_line!(line, order: order, date: date) }
  end

  # Re-checks every open imported order. Returns the number of orders checked.
  def self.recheck_open_orders!
    orders = CustomerOrder.where.not(external_order_no: [nil, ''])
                          .where(order_status: OPEN_STATUSES)
                          .includes(:customer, customer_order_products: :product)
    orders.find_each { |order| check_order!(order) }
    orders.count
  end

  def self.check_line!(line, order:, date:)
    attrs = { expected_price: nil, price_check: nil, quote_product_id: nil, pricing_rule_id: nil,
              price_checked_at: Time.current }

    if line.product && order.customer_id
      result = PricingRuleService.lookup(order.customer_id, line.product, date: date)
      if result.nil? || result[:price].nil?
        attrs[:price_check] = 'no_price'
      else
        attrs[:expected_price]   = result[:price]
        attrs[:quote_product_id] = result[:quote_product]&.id
        attrs[:pricing_rule_id]  = result[:rule]&.id
        attrs[:price_check]      = status_for(line.price, result)
      end
    end

    line.update_columns(attrs)
  end

  def self.status_for(actual, result)
    return 'match' if actual && (actual.to_d - result[:price]).abs < TOLERANCE
    result[:quote_product] ? 'lock_mismatch' : 'rule_mismatch'
  end
end
