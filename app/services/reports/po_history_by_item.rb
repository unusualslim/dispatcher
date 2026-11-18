module Reports
  # Purchase history line by line: what was bought, from whom, when and at what cost, by item or by vendor.
  class PoHistoryByItem < Base
    report title: 'Purchase history by item', area: :purchasing,
           description: 'Every PO line received in the period with vendor, quantity and unit cost, to compare ' \
                        'vendors and see price changes per item.',
           filters: %i[dates product_id vendor_id location_id category]

    def self.default_from(today)
      today - 12.months
    end

    def columns
      [column(:product_id, 'Item'), column(:description, 'Description'), column(:received, 'Received', :date),
       column(:vendor, 'Vendor'), column(:po, 'PO'), column(:warehouse, 'Warehouse'),
       column(:quantity, 'Quantity', :decimal, total: true), column(:unit_cost, 'Unit cost', :price),
       column(:landed_cost, 'Landed cost', :price), column(:amount, 'Amount', :currency, total: true)]
    end

    def rows
      @rows ||= lines.map { |line| row(line) }.sort_by { |r| [r[:product_id].to_s, r[:received] || Date.new(1900)] }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.purchase_order_path(row[:po_id]) if column.key == :po
    end

    private

    def lines
      scope = PurchaseOrderLineItem.joins(:purchase_order).includes(:product, purchase_order: %i[vendor location])
                                   .where(purchase_orders: { voided_at: nil, received_at: time_range })
                                   .where.not(product_id: nil)
      scope = scope.where(product_id: filters[:product_id]) if filters[:product_id]
      scope = scope.where(purchase_orders: { vendor_id: filters[:vendor_id] }) if filters[:vendor_id]
      scope = scope.where(purchase_orders: { location_id: filters[:location_id] }) if filters[:location_id]
      scope = scope.joins(:product).where(products: { category: filters[:category] }) if filters[:category]
      scope.to_a
    end

    def row(line)
      po = line.purchase_order
      { po_id: po.id, product_id: line.product_id, description: line.display_name, received: po.received_at&.to_date,
        vendor: po.vendor&.name || po.vendor_id, po: po.display_number,
        warehouse: po.location&.pdi_site_code.presence || po.location&.company_name, quantity: line.quantity.to_d,
        unit_cost: line.unit_cost&.to_d, landed_cost: po.landed_unit_cost(line)&.to_d,
        amount: line.quantity.to_d * line.unit_cost.to_d }
    end
  end
end
