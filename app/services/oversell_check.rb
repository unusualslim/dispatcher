# Blocks overselling on orders entered in the app: a new or changed line for a stocked item we buy (not made to
# order, not fuel) can't ask for more than the warehouse has left after other open orders take theirs. Made items
# are left alone: a shortage there becomes production. PDI's synced orders never go through this.
class OversellCheck
  OPEN_STATUSES = Reports::OpenOrderLines::STATUSES

  def initialize(order)
    @order = order
  end

  # Messages, one per item that would be oversold.
  def problems
    checked_lines.group_by { |line| [line.product, warehouse_id(line)] }.filter_map do |(product, warehouse), lines|
      wanted = lines.sum { |line| line.quantity.to_d }
      on_hand = on_hand(product, warehouse)
      committed = committed(product, warehouse)
      available = [on_hand - committed, 0].max
      message(product, wanted, available, on_hand, committed) if wanted > available
    end
  end

  private

  attr_reader :order

  def checked_lines
    order.customer_order_products.reject(&:marked_for_destruction?).select do |line|
      changed = line.new_record? || line.quantity_changed? || line.product_id_changed?
      changed && line.quantity.to_d.positive? && stocked_buy_item?(line.product)
    end
  end

  def stocked_buy_item?(product)
    product&.inventory_item? && !product.produced? && product.reporting_group&.item_type != 'fuel'
  end

  def warehouse_id(line)
    line.location_id || order.ship_from_location_id
  end

  def on_hand(product, warehouse)
    stock = LocationProduct.where(product_id: product.id)
    (warehouse ? stock.where(location_id: warehouse) : stock).sum(:quantity).to_d
  end

  # Quantity on other open orders' lines for the item at that warehouse.
  def committed(product, warehouse)
    lines = CustomerOrderProduct.joins(:customer_order).where(product_id: product.id)
                                .where(customer_orders: { order_status: [*OPEN_STATUSES, nil] }) # app orders: blank
    lines = lines.where.not(customer_order_id: order.id) if order.persisted?
    if warehouse
      lines = lines.where('customer_order_products.location_id = :w OR (customer_order_products.location_id IS NULL ' \
                          'AND customer_orders.ship_from_location_id = :w)', w: warehouse)
    end
    lines.where('customer_order_products.quantity > 0').sum(:quantity).to_d
  end

  def message(product, wanted, available, on_hand, committed)
    fmt = ->(n) { n.round(3).to_s('F').delete_suffix('.0') }
    "#{product.id} #{product.name}: ordering #{fmt.call(wanted)}, only #{fmt.call(available)} available " \
      "(#{fmt.call(on_hand)} on hand, #{fmt.call(committed)} on other open orders)"
  end
end
