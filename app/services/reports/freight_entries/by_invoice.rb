module Reports
  module FreightEntries
    # PDI orders invoiced in the period and their freight items (CustomerOrder#pdi_freight_items). A load's
    # purchase charge (FPLSPLIT…) repeats on every order of the load, so each order gets an even share.
    class ByInvoice
      def initialize(filters)
        @filters = filters
      end

      def entries
        @entries ||= begin
          counts = load_counts
          orders.flat_map { |order| order.pdi_freight_items.map { |raw| entry(order, raw, counts) } }
        end
      end

      def hauls
        orders.map do |order|
          Haul.new(truck_key: truck_key(order), truck: truck(order), driver: order.pdi_driver,
                   order_no: order.external_order_no, gallons: order.pdi_gallons.to_d)
        end
      end

      private

      def orders
        @orders ||= scope.includes(:customer, :location)
                         .sort_by { |o| [truck_key(o), o.invoice_date, o.external_order_no.to_s] }
      end

      def scope
        scope = CustomerOrder.where(invoice_date: @filters.range).where.not(pdi_gallons: nil)
                             .where.not(order_status: FinancialDashboard::Sales::CANCELLED)
        scope = scope.where(customer_id: @filters[:customer_id]) if @filters[:customer_id]
        @filters[:carrier_id] ? scope.where(pdi_carrier_id: @filters[:carrier_id]) : scope
      end

      def entry(order, raw, counts)
        load = loads[order.external_order_no]
        shared = counts[[raw['load'], raw['charge']]] if raw['load']
        fields = { business_date: load&.business_date, load: load_label(load, shared), amount: share(raw, shared) }
        Entry.new(**order_fields(order), **FreightEntries.item_fields(raw), **fields)
      end

      def order_fields(order)
        { truck_key: truck_key(order), truck: truck(order), driver: order.pdi_driver, order: order,
          order_no: order.external_order_no }
      end

      # "34779 · 1 of 3": the PDI load, and this order's share of a charge split over the load's orders.
      def load_label(load, shared)
        [load&.label, shared && "1 of #{shared}"].compact.join(' · ').presence
      end

      def share(raw, shared)
        amount = raw['amount'].to_d
        shared ? (amount / shared).round(2) : amount
      end

      # Order number => its PDI fuel load (for the business date and load number shown).
      def loads
        @loads ||= PdiFuelLoad.containing_orders(orders.map(&:external_order_no)).order(:business_date)
                              .each_with_object({}) { |load, map| load.order_nos.each { |no| map[no] ||= load } }
      end

      # [load key, charge] => orders carrying it, including orders outside the period.
      def load_counts
        keys = orders.flat_map { |order| order.pdi_freight_items.filter_map { |item| item['load'] } }.uniq
        return {} if keys.empty?

        CustomerOrder.where.not(order_status: FinancialDashboard::Sales::CANCELLED)
                     .from('customer_orders, jsonb_array_elements(customer_orders.pdi_freight_items) item')
                     .where("item->>'load' IN (?)", keys)
                     .group(Arel.sql("item->>'load'"), Arel.sql("item->>'charge'")).count
      end

      def truck_key(order) = FreightEntries.truck_key(order.pdi_vehicle_id, order.carrier)

      def truck(order)
        return order.pdi_vehicle || "Vehicle #{order.pdi_vehicle_id}" if order.pdi_vehicle_id

        FreightEntries.no_truck(order.carrier)
      end
    end
  end
end
