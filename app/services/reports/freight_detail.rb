module Reports
  class FreightDetail < Base
    report title: 'Freight detail', area: :sales, flag: :costs,
           description: 'Every freight item PDI recorded: per-gallon freight, fuel surcharges, split load fees and ' \
                        'other charges, sale and purchase side, by truck. By invoice date: orders invoiced in the ' \
                        'period, a load charge split evenly over its orders. By load business date: fuel loads as ' \
                        'on PDI\'s FI Fuel Delivery Report (lines may differ by a cent; PDI rounds its rates).',
           filters: %i[dates date_basis carrier_id customer_id]

    def columns
      [column(:truck, 'Truck'), column(:driver, 'Driver'), column(:business_date, 'Business date', :date),
       column(:invoiced, 'Invoiced', :date), column(:delivered, 'Delivered', :date), column(:load, 'Load'),
       column(:bol, 'BOL'), column(:order_no, 'Order'), column(:customer, 'Customer'), column(:ship_to, 'Ship-to'),
       column(:side, 'Side'), column(:charge, 'Charge'), column(:product, 'Product'),
       column(:quantity, 'Qty', :decimal), column(:rate, 'Rate', :price),
       column(:sale, 'Sale', :currency, total: true), column(:cost, 'Purchase', :currency, total: true)]
    end

    def rows
      @rows ||= FreightEntries.for(filters).entries.map { |entry| entry_row(entry) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.customer_order_path(row[:order]) if column.key == :order_no && row[:order]
    end

    private

    def entry_row(entry)
      { truck: entry.truck, driver: entry.driver, business_date: entry.business_date, load: entry.load,
        bol: entry.bol, order_no: entry.order_no, side: entry.side.capitalize, charge: entry.charge,
        product: entry.product, quantity: entry.quantity, rate: entry.rate, sale: entry.sale, cost: entry.cost,
        **order_columns(entry.order) }
    end

    def order_columns(order)
      { order: order, invoiced: order&.invoice_date, delivered: order&.required_delivery_date,
        customer: order&.customer&.name, ship_to: order&.location&.company_name }
    end
  end
end
