# An order's margin after freight: product sales against product cost at standard (BOM cost when an item has no
# standard), plus freight billed less freight cost (the order's Freight card charges). Lines without a cost are
# counted and left out of the cost side, so the margin never looks better by accident without saying so.
class OrderMargin
  attr_reader :order

  def initialize(order)
    @order = order
  end

  def lines
    @lines ||= order.customer_order_products.includes(product: :standard_cost_histories).select(&:product)
  end

  def sales
    lines.sum(0.to_d) { |line| line.quantity.to_d * line.price.to_d }
  end

  def product_cost
    costed.sum(0.to_d) { |line, cost| line.quantity.to_d * cost }
  end

  def uncosted
    lines.size - costed.size
  end

  def freight_billed
    order.order_freight_charges.sale.sum(:amount).to_d
  end

  def freight_cost
    order.order_freight_charges.purchase.sum(:amount).to_d
  end

  def margin
    sales + freight_billed - product_cost - freight_cost
  end

  def margin_share
    revenue = sales + freight_billed
    margin / revenue if revenue.positive?
  end

  private

  def costed
    @costed ||= lines.filter_map do |line|
      cost = line.product.current_standard_cost&.to_d || line.product.bom_standard_cost
      [line, cost] if cost
    end
  end
end
