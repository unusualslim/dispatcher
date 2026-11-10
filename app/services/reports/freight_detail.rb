module Reports
  class FreightDetail < Base
    include TruckFreight

    report title: 'Freight detail', area: :sales, flag: :costs,
           description: 'Every freight item PDI recorded on orders invoiced in the period: per-gallon freight, ' \
                        'fuel surcharges, split load fees and other charges, sale and purchase side, by truck. ' \
                        'A load charge is split evenly over the orders on the load.',
           filters: %i[dates customer_id]

    def columns
      [column(:truck, 'Truck'), column(:driver, 'Driver'), column(:invoiced, 'Invoiced', :date),
       column(:delivered, 'Delivered', :date), column(:order_no, 'Order'), column(:customer, 'Customer'),
       column(:ship_to, 'Ship-to'), column(:side, 'Side'), column(:charge, 'Charge'), column(:product, 'Product'),
       column(:bol, 'BOL'),
       column(:load, 'Load'), column(:quantity, 'Qty', :decimal), column(:rate, 'Rate', :price),
       column(:sale, 'Sale', :currency, total: true), column(:cost, 'Purchase', :currency, total: true)]
    end

    def rows
      @rows ||= begin
        orders = freight_orders.includes(:customer, :location)
                               .sort_by { |o| [*truck_sort(o), o.invoice_date, o.external_order_no.to_s] }
        freight_items(orders).map { |item| item_row(item) }
      end
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.customer_order_path(row[:order]) if column.key == :order_no
    end

    private

    def item_row(item)
      order_columns(item.order).merge(
        side: item.side.capitalize, charge: item.charge, product: item.product, bol: item.bol,
        load: item.load && "#{item.load} (1 of #{item.load_orders})", quantity: item.quantity, rate: item.rate,
        sale: item.sale, cost: item.cost
      )
    end

    def order_columns(order)
      { order: order, truck: truck_name(order), driver: order.pdi_driver, invoiced: order.invoice_date,
        delivered: order.required_delivery_date,
        order_no: order.external_order_no, customer: order.customer&.name, ship_to: order.location&.company_name }
    end
  end
end
