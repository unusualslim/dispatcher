# Takes shipped PDI orders out of stock as "sale" movements, and keeps them in step as PDI changes the
# order: when a line's quantity, product or warehouse changes, or the order is cancelled, the old sale
# movements are reversed and the current ones posted.
#
# Only PDI orders (PDI bills them) shipped on or after the inventory start date (opening balances
# already include earlier sales). Lines with no warehouse, dropship lines and non-inventory products are
# left out. A line takes out what shipped (shipped_quantity), or the ordered quantity when PDI didn't say.
module InventorySales
  SHIPPED_STATUSES = %w[shipped released_for_billing billed delivered accepted_by_site credited].freeze

  module_function

  def sync!(order)
    start = InventoryRevaluation.start_date
    return unless start

    posted = posted_quantities(order)
    wanted = wanted_quantities(order, start)
    (posted.keys | wanted.keys).each do |key|
      qty = wanted.fetch(key, 0.to_d)
      next if posted.fetch(key, 0.to_d) == qty

      repost!(order, *key, qty)
    end
  end

  # { [product_id, location_id] => quantity out } from the order's sale movements in effect.
  def posted_quantities(order)
    sales(order).in_effect.each_with_object(Hash.new(0.to_d)) do |txn, totals|
      totals[[txn.product_id, txn.location_id]] -= txn.signed_quantity
    end
  end

  def wanted_quantities(order, start)
    return {} unless shipped?(order, start)

    lines = order.customer_order_products.includes(product: :reporting_group).select { |line| stocked?(line) }
    lines.group_by { |line| [line.product_id, line.location_id] }
         .transform_values { |group| group.sum { |line| shipped_quantity(line) } }
         .reject { |_, qty| qty.zero? }
  end

  # What shipped, or the ordered quantity when PDI didn't say.
  def shipped_quantity(line)
    (line.shipped_quantity || line.quantity).to_d
  end

  def shipped?(order, start)
    order.external_order_no.present? && SHIPPED_STATUSES.include?(order.order_status) && ship_date(order) >= start
  end

  # Ships from one of our warehouses, and the product is kept in inventory.
  def stocked?(line)
    line.location_id && !line.dropship? && line.product&.inventory_item?
  end

  def repost!(order, product_id, location_id, qty)
    sales(order).in_effect.where(product_id: product_id, location_id: location_id).find_each do |txn|
      InventoryPosting.reverse!(txn, source: order, reference: order.external_order_no)
    end
    return if qty.zero?

    InventoryPosting.post!(product: Product.find(product_id), location: Location.find(location_id), quantity: -qty,
                           movement_type: 'sale', source: order, reference: order.external_order_no,
                           occurred_on: ship_date(order), notes: "Shipped on PDI order #{order.external_order_no}")
  end

  def sales(order)
    InventoryTransaction.where(transactable: order, movement_type: 'sale')
  end

  # Invoice date when billed, else the delivery date, else the order date.
  def ship_date(order)
    order.invoice_date || order.required_delivery_date || order.order_date&.to_date || Date.current
  end
end
