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
        record = CustomerOrder.find_or_initialize_by(external_order_no: @order.order_no)
        action = record.new_record? ? :created : :updated
        record.assign_attributes(attributes(record))
        changed = record.changed?
        record.save! if changed
        sync_lines(record) || changed ? action : :unchanged
      end
    end

    private

    def attributes(record)
      destination = Destination.new(@order, current: record.location)
      @order.attrs.merge(customer: destination.customer, location: destination.location)
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
      lines.map do |line|
        code = line.respond_to?(:product_code) ? line.product_code : line.product_name
        [code.to_s, line.quantity.to_i, line.price&.to_d.to_s]
      end.sort
    end

    def line_attrs(line)
      product = Product.find_by(id: line.product_code)
      { product_name: line.product_code, product_id: product&.id, quantity: line.quantity, price: line.price,
        item_type: product&.order_item_type || 'buy' }
    end
  end
end
