module Reports
  # Freight items PDI recorded on invoiced orders (CustomerOrder#pdi_freight_items, from PdiOrders::TruckFreight).
  # A load's purchase charge (FPLSPLIT…) repeats on every order of the load, so each order gets an even share.
  module TruckFreight
    NO_TRUCK = 'No truck'.freeze

    # One freight amount on one order; amount is the order's share for load charges.
    Item = Struct.new(:order, :side, :charge, :product, :quantity, :rate, :amount, :load, :load_orders, :bol,
                      keyword_init: true) do
      def sale = side == 'sale' ? amount : 0
      def cost = side == 'purchase' ? amount : 0
    end

    private

    # PDI orders with freight data invoiced in the period (orders not yet invoiced aren't included).
    def freight_orders
      scope = CustomerOrder.where(invoice_date: range).where.not(pdi_gallons: nil)
                           .where.not(order_status: FinancialDashboard::Sales::CANCELLED)
      scope = scope.where(customer_id: filters[:customer_id]) if filters[:customer_id]
      scope
    end

    def freight_items(orders)
      counts = load_counts(orders)
      orders.flat_map do |order|
        order.pdi_freight_items.map { |raw| build_item(order, raw, counts.fetch([raw['load'], raw['charge']], 1)) }
      end
    end

    def build_item(order, raw, load_orders)
      amount = raw['amount'].to_d
      Item.new(order: order, side: raw['side'], charge: raw['charge'], product: raw['product'],
               quantity: raw['quantity']&.to_d, rate: raw['rate']&.to_d, bol: raw['bol'], load: raw['load'],
               load_orders: (load_orders if raw['load']),
               amount: raw['load'] ? (amount / load_orders).round(2) : amount)
    end

    # [load key, charge] => orders carrying it, including orders outside the period.
    def load_counts(orders)
      keys = orders.flat_map { |order| order.pdi_freight_items.filter_map { |item| item['load'] } }.uniq
      return {} if keys.empty?

      CustomerOrder.where.not(order_status: FinancialDashboard::Sales::CANCELLED)
                   .from('customer_orders, jsonb_array_elements(customer_orders.pdi_freight_items) item')
                   .where("item->>'load' IN (?)", keys)
                   .group(Arel.sql("item->>'load'"), Arel.sql("item->>'charge'")).count
    end

    def truck_name(order)
      return order.pdi_vehicle || "Vehicle #{order.pdi_vehicle_id}" if order.pdi_vehicle_id

      "#{NO_TRUCK} (#{order.carrier || 'no carrier'})"
    end

    # Trucks first by number, then the no-truck carriers.
    def truck_sort(order)
      order.pdi_vehicle_id ? [0, order.pdi_vehicle_id.to_i, order.pdi_vehicle_id] : [1, 0, order.carrier.to_s]
    end

    def per_gallon(sale, cost, gallons)
      return {} unless gallons.positive?

      { sale_per_gallon: (sale / gallons).round(4), cost_per_gallon: (cost / gallons).round(4) }
    end
  end
end
