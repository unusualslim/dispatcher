module CustomerOrdersHelper
  # Columns on the Customer Orders table: key (= CustomerOrderListQuery sort key), header, shown by default.
  # Viewers can hide or show any of them (remembered per browser).
  ORDER_LIST_COLUMNS = [
    ['order', 'Order', true], ['status', 'Status', true], ['customer', 'Customer', true],
    ['ship_to', 'Ship-to', true], ['ship_from', 'Ship from', true], ['products', 'Products', true],
    ['qty', 'Qty', true], ['total', 'Total', true], ['order_date', 'Order date', true],
    ['delivery', 'Delivery', true], ['po', 'Customer PO', false], ['invoice', 'Invoice #', true],
    ['invoice_date', 'Invoice date', false], ['salesperson', 'Salesperson', false], ['carrier', 'Carrier', false],
    ['driver', 'Driver', false], ['dispatch', 'Dispatch', true]
  ].freeze

  def order_list_columns
    sees?(:customer_pricing) ? ORDER_LIST_COLUMNS : ORDER_LIST_COLUMNS.reject { |key, *| key == 'total' }
  end

  def order_status_badge_class(status)
    case status
    when *CustomerOrder::ACTIVE_STATUSES then 'bg-primary'
    when 'Billed', 'Delivered', 'Accepted by Site' then 'bg-success'
    when 'Expired', 'Rejected by Site' then 'bg-warning text-dark'
    when 'Cancelled as Order', 'Cancelled as Quote' then 'bg-danger'
    else 'bg-secondary'
    end
  end

  # The order's number as people know it: PDI's order no, else the number the app gave it, else its app id.
  def order_list_number(order)
    order.external_order_no.presence || order.pdi_order_number.presence || "##{order.id}"
  end

  # Where the order ships from: its ship-from, else the warehouses on its lines (PDI orders carry them per line).
  def order_list_ship_from(order)
    return order.ship_from_location.company_name if order.ship_from_location

    order.customer_order_products.filter_map { |line| line.location&.company_name || line.warehouse.presence }
         .uniq.join(', ')
  end

  def order_list_products(order)
    names = order.customer_order_products.map { |line| line.product&.name || line.product_name }.compact.uniq
    names.size > 2 ? "#{names.first(2).join(', ')} +#{names.size - 2} more" : names.join(', ')
  end

  def order_list_qty(order)
    total = order.customer_order_products.sum { |line| line.quantity.to_d }
    total.zero? ? '' : number_with_delimiter(total.to_i)
  end

  def order_list_total(order)
    lines = order.customer_order_products.select(&:price)
    lines.empty? ? '' : number_to_currency(lines.sum { |line| line.quantity.to_d * line.price })
  end
end
