module Reports
  # What is coming in at each location, when, and from whom: the lines of purchase orders that have been
  # ordered (approved or submitted) and not yet received, by expected delivery date. "Who" is the vendor and the
  # freight carrier when one is set. Orders with no expected date are listed too (they have no "when" yet).
  class IncomingReceipts < Base
    OPEN_STATUSES = %w[approved submitted].freeze

    report title: 'Incoming receipts', area: :inventory,
           description: 'Open purchase orders by location and expected date: what is coming in, when, ' \
                        'from which vendor and carrier. Orders with no expected date are listed at the end.',
           filters: %i[dates location_id vendor_id product_id]

    # A week back keeps recently overdue orders in view; two weeks ahead is the receiving horizon.
    def self.default_from(today)
      today - 7
    end

    def self.default_to(today)
      today + 14
    end

    def columns
      [column(:expected, 'Expected', :date), column(:days, 'Days out', :number), column(:location, 'Location'),
       column(:po_no, 'PO'), column(:vendor, 'Vendor'), column(:carrier, 'Carrier'), column(:product, 'Product'),
       column(:quantity, 'Qty', :decimal), column(:package, 'Package'), column(:status, 'Status')]
    end

    def rows
      @rows ||= scope.includes(:product, :location, purchase_order: %i[vendor freight_vendor location])
                     .sort_by { |line| sort_key(line) }.map { |line| line_row(line) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.purchase_order_path(row[:purchase_order]) if column.key == :po_no
    end

    private

    def scope
      scope = PurchaseOrderLineItem.joins(:purchase_order)
                                   .where(purchase_orders: { status: OPEN_STATUSES, voided_at: nil })
                                   .where(expected_in_window, range.begin, range.end)
      scope = narrowed_by_ids(scope)
      filters[:location_id] ? in_location(scope) : scope
    end

    def narrowed_by_ids(scope)
      scope = scope.where(purchase_orders: { vendor_id: filters[:vendor_id] }) if filters[:vendor_id]
      filters[:product_id] ? scope.where(product_id: filters[:product_id]) : scope
    end

    def in_location(scope)
      scope.where('COALESCE(purchase_order_line_items.location_id, purchase_orders.location_id) = ?',
                  filters[:location_id])
    end

    def expected_in_window
      'purchase_orders.expected_delivery_date IS NULL OR purchase_orders.expected_delivery_date BETWEEN ? AND ?'
    end

    # By location, then date (undated last), then PO.
    def sort_key(line)
      order = line.purchase_order
      [place(line)&.company_name.to_s, order.expected_delivery_date ? 0 : 1, order.expected_delivery_date,
       order.display_number.to_s, line.id]
    end

    def place(line)
      line.location || line.purchase_order.location
    end

    def line_row(line)
      order_columns(line.purchase_order, place(line)).merge(item_columns(line))
    end

    def order_columns(order, location)
      { purchase_order: order, expected: order.expected_delivery_date, days: days_out(order),
        location: location&.company_name || 'No location', po_no: order.display_number,
        vendor: order.vendor&.label, carrier: order.freight_vendor&.label, status: order.status.humanize }
    end

    def item_columns(line)
      { product: line.product&.name || line.product_name, quantity: line.quantity, package: line.package_code }
    end

    def days_out(order)
      (order.expected_delivery_date - Date.current).to_i if order.expected_delivery_date
    end
  end
end
