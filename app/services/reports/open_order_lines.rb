module Reports
  # The open order report the operations group used in their previous system: one row per open order line, with
  # stock at the line's warehouse handed out first come, first served (picking / staged orders first, then by
  # requested date), and what each line is waiting on: ready to ship, picking, production, purchase (backorder) or a
  # return. "Show" picks one of those slices, like their Allocated / Production / Backorder / RMA sheets.
  class OpenOrderLines < Base # rubocop:disable Metrics/ClassLength
    # Open sales orders: the active statuses less quotes and orders already released for billing.
    STATUSES = (CustomerOrder::ACTIVE_STATUSES - ['Quote', 'Released for Billing']).freeze
    PICKING = %w[released_for_picking picking_in_progress staged truck_loaded].freeze # enum keys
    DISPOSITIONS = {
      'ready' => 'Ready to ship', 'picking' => 'Picking / staged', 'production' => 'Needs production',
      'backorder' => 'Backorder (purchase)', 'return' => 'Return', 'direct' => 'Direct / non-stock'
    }.freeze
    VIEWS = DISPOSITIONS.except('direct').merge('late' => 'Past requested date').freeze

    report title: 'Open order report', area: :sales,
           description: 'Every open order line with stock on hand, what it is waiting on (production, purchase, ' \
                        'picking) and how late it is. Stock goes to picking orders first, then by requested date.',
           filters: %i[view customer_id product_id location_id category]

    def columns
      [column(:order, 'Order'), column(:status, 'Status'), column(:order_date, 'Ordered', :date),
       column(:requested, 'Requested', :date), column(:days_late, 'Days late', :number),
       column(:customer, 'Customer'), column(:ship_to, 'Ship-to'), column(:product_id, 'Item'),
       column(:description, 'Description'), column(:group, 'Group'), column(:package, 'UOM'),
       column(:warehouse, 'Warehouse'), column(:ordered, 'Ordered qty', :decimal, total: true),
       column(:available, 'Available', :decimal), column(:short, 'Short', :decimal, total: true),
       column(:disposition, 'Disposition'), column(:carrier, 'Carrier'), column(:sales_rep, 'Sales rep')]
    end

    def rows
      @rows ||= begin
        all = allocate(lines).map { |line, available| row(line, available) }
        view = filters[:view]
        all = all.select { |r| view == 'late' ? r[:days_late].to_i.positive? : r[:disposition_key] == view } if view
        all.sort_by { |r| [r[:requested] || Date.new(2100), r[:order].to_s] }
      end
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.customer_order_path(row[:order_id]) if column.key == :order
    end

    private

    def today
      Date.current
    end

    def lines
      scope = CustomerOrderProduct.joins(:customer_order).where(customer_orders: { order_status: [*STATUSES, nil] })
                                  .includes({ customer_order: %i[customer location ship_from_location] }, :location,
                                            product: :reporting_group)
      scope = scope.where(customer_orders: { customer_id: filters[:customer_id] }) if filters[:customer_id]
      scope = scope.where(product_id: filters[:product_id]) if filters[:product_id]
      scope = scope.where(location_id: filters[:location_id]) if filters[:location_id]
      scope = scope.joins(:product).where(products: { category: filters[:category] }) if filters[:category]
      scope.to_a
    end

    # [[line, stock available to it]]: each product / warehouse's stock handed out in turn.
    def allocate(lines)
      stock = on_hand(lines.filter_map(&:product_id).uniq)
      left = Hash.new do |h, (product_id, location_id)|
        h[[product_id, location_id]] = stock_for(stock, product_id, location_id)
      end
      lines.sort_by { |line| priority(line) }.map do |line|
        next [line, nil] unless stocked?(line)

        key = [line.product_id, warehouse_id(line)]
        available = left[key]
        left[key] = [available - line.quantity.to_d, 0].max
        [line, available]
      end
    end

    def priority(line)
      order = line.customer_order
      [PICKING.include?(order.order_status) ? 0 : 1, order.required_delivery_date || order.order_date || Date.new(2100),
       order.id, line.id]
    end

    def stocked?(line)
      product = line.product
      product && line.quantity.to_d.positive? && product.inventory_item? &&
        product.reporting_group&.item_type != 'fuel'
    end

    def warehouse_id(line)
      line.location_id || line.customer_order.ship_from_location_id
    end

    # { product_id => { location_id => quantity } }
    def on_hand(product_ids)
      LocationProduct.where(product_id: product_ids).group(:product_id, :location_id).sum(:quantity)
                     .each_with_object(Hash.new do |h, k|
                                         h[k] = {}
                                       end) { |((product, location), qty), map| map[product][location] = qty.to_d }
    end

    # A line with no warehouse may draw on the product's stock anywhere.
    def stock_for(stock, product_id, location_id)
      by_location = stock[product_id]
      location_id ? by_location.fetch(location_id, 0.to_d) : by_location.values.sum(0.to_d)
    end

    def row(line, available)
      order = line.customer_order
      requested = order.required_delivery_date
      key = disposition(line, available)
      { order_id: order.id, order: order.external_order_no.presence || "##{order.id}",
        status: CustomerOrder.order_statuses[order.order_status],
        order_date: order.order_date, requested: requested,
        days_late: days_late(requested),
        customer: order.customer&.name, ship_to: order.location&.company_name, product_id: line.product_id,
        description: line.product&.name || line.product_name, group: line.product&.category,
        package: line.product&.pdi_package_code, warehouse: warehouse_label(line), ordered: line.quantity.to_d,
        available: available, short: short(line, available), disposition: DISPOSITIONS[key], disposition_key: key,
        carrier: carriers[order.pdi_carrier_id] || order.carrier, sales_rep: order.salesperson }
    end

    def days_late(requested)
      late = requested && (today - requested).to_i
      late if late&.positive?
    end

    def short(line, available)
      return unless available

      [line.quantity.to_d - available, 0].max.nonzero?
    end

    def disposition(line, available)
      return 'return' if line.quantity.to_d.negative?
      return 'picking' if PICKING.include?(line.customer_order.order_status)
      return 'direct' if available.nil?
      return 'ready' if available >= line.quantity.to_d

      line.product.produced? ? 'production' : 'backorder'
    end

    def warehouse_label(line)
      location = line.location || line.customer_order.ship_from_location
      location&.pdi_site_code.presence || location&.company_name || line.warehouse
    end

    def carriers
      @carriers ||= PdiCarrier.pluck(:pdi_carrier_id, :name).to_h
    end
  end
end
