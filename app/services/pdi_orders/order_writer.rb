module PdiOrders
  # Creates or updates the CustomerOrder for one PDI order (matched on external_order_no, like the FTP
  # import) and its lines. PDI bills, so its lines and prices win; changed lines are price-checked again.
  class OrderWriter
    def initialize(order)
      @order = order
    end

    # :created, :updated or :unchanged
    def save!
      CustomerOrder.transaction do
        record = find_record
        action = record.new_record? ? :created : :updated
        changed = save_order(record)
        lines_changed = sync_lines(record)
        InventorySales.sync!(record) # shipped orders take their lines out of stock
        lines_changed || changed ? action : :unchanged
      end
    end

    private

    def sent_from_app
      CustomerOrder.find_by(pdi_order_number: @order.order_no, external_order_no: nil) ||
        FuelOrderPush.order_for_reference(@order.alternate_reference)
    end

    # By PDI order number; else an app order sent with Send to PDI (by the number it was sent under, or our
    # reference APP123), linked.
    def find_record
      CustomerOrder.find_by(external_order_no: @order.order_no) ||
        sent_from_app&.tap do |order|
          order.assign_attributes(external_order_no: @order.order_no, pdi_push_status: 'sent')
        end ||
        CustomerOrder.new(external_order_no: @order.order_no)
    end

    # True when the order itself changed.
    def save_order(record)
      record.assign_attributes(attributes(record))
      changed = record.changed?
      record.save! if changed
      record.customer&.record_pdi_credit!(@order.credit)
      changed
    end

    def attributes(record)
      destination = Destination.new(@order, current: record.location)
      @order.attrs.merge(customer: destination.customer, location: destination.location, **carrier,
                         **@order.truck_freight)
    end

    # The carrier's name for display (from master data), when PDI sent a carrier.
    def carrier
      return {} unless @order.carrier_id

      { carrier: PdiCarrier.name_for(@order.carrier_id) || "PDI carrier #{@order.carrier_id}" }
    end

    def sync_lines(record)
      return false if signature(@order.lines) == signature(record.customer_order_products)

      record.customer_order_products.destroy_all
      @order.lines.each { |line| record.customer_order_products.create!(line_attrs(line)) }
      record.sync_approximate_amount
      PriceCheckService.check_order!(record)
      true
    end

    def signature(lines)
      lines.map { |line| line_key(line) }.sort
    end

    # A feed line (OrderNode::Line) or a saved order line, compared field by field.
    def line_key(line)
      feed = line.respond_to?(:product_code)
      [(feed ? line.product_code : line.product_name).to_s, line.quantity.to_i,
       *[line.shipped_quantity, line.price, line.tax_per_unit].map { |n| n&.to_d.to_s },
       line.price_includes_taxes, (feed ? line.site : line.warehouse).to_s]
    end

    def line_attrs(line)
      product = Product.find_by(id: line.product_code)
      { product_name: line.product_code, product_id: product&.id, quantity: line.quantity,
        shipped_quantity: line.shipped_quantity, price: line.price, tax_per_unit: line.tax_per_unit,
        price_includes_taxes: line.price_includes_taxes,
        item_type: product&.order_item_type || 'buy', warehouse: line.site, location: Warehouses.for_line(line) }
    end
  end
end
