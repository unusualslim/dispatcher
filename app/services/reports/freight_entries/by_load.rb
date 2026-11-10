module Reports
  module FreightEntries
    # PDI fuel loads with a business date in the period (PdiFuelLoad), as PDI's FI Fuel Delivery Report:
    # purchase freight and per-load charges from the load, sale freight from the orders on it (each order once).
    class ByLoad
      def initialize(filters)
        @filters = filters
      end

      def entries
        @entries ||= begin
          seen = Set.new
          loads.flat_map { |load| load_entries(load, load.order_nos.filter_map { |no| orders[no] if seen.add?(no) }) }
        end
      end

      # Gallons lifted per load line (before the line freight is split into components).
      def hauls
        loads.flat_map do |load|
          load.items.select { |raw| line?(raw) && customer?(orders[raw['order_no']]) }.map { |raw| haul(load, raw) }
        end
      end

      private

      # The load's purchase lines and charges, then the sale freight of orders not already on an earlier load.
      def load_entries(load, new_orders)
        load.items.flat_map { |raw| purchase_entries(load, raw) } +
          new_orders.flat_map { |order| sale_entries(load, order) }
      end

      def loads
        @loads ||= scope.to_a.select { |load| customer_load?(load) }
                        .sort_by { |load| [truck_key(load), load.business_date, load.load_no.to_i] }
      end

      def scope
        scope = PdiFuelLoad.where(business_date: @filters.range)
        @filters[:carrier_id] ? scope.where(carrier_id: @filters[:carrier_id]) : scope
      end

      def orders
        @orders ||= CustomerOrder.where(external_order_no: scope.pluck(:order_nos).flatten.uniq)
                                 .includes(:customer, :location).index_by(&:external_order_no)
      end

      def customer_load?(load)
        !@filters[:customer_id] || load.order_nos.any? { |no| customer?(orders[no]) }
      end

      def customer?(order)
        !@filters[:customer_id] || order&.customer_id.to_s == @filters[:customer_id].to_s
      end

      def haul(load, raw)
        Haul.new(truck_key: truck_key(load), truck: truck(load), driver: driver(load), order_no: raw['order_no'],
                 gallons: raw['quantity'].to_d)
      end

      def line?(raw) = raw['order_no'] && raw['charge'] == PdiOrders::TruckFreight::LINE_FREIGHT

      # Load charges (no order) stay with the load; lines for other customers' orders drop out. Line freight is
      # split into PDI's components (Breakdown), leaving out the ones the load carries as charges.
      def purchase_entries(load, raw)
        order = orders[raw['order_no']]
        return [] if raw['order_no'] && !customer?(order)

        breakdown.split(raw.merge('side' => 'purchase'), raw['order_no'], load_charges(load))
                 .map { |part| entry(load, order, part, raw['order_no']) }
      end

      def load_charges(load) = load.items.filter_map { |item| item['charge'] unless item['order_no'] }

      def sale_entries(load, order)
        return [] unless customer?(order)

        sales = order.pdi_freight_items.select { |raw| raw['side'] == 'sale' }
        sales.flat_map do |raw|
          breakdown.split(raw, order.external_order_no, sales.pluck('charge'))
                   .map { |part| entry(load, order, part, order.external_order_no) }
        end
      end

      def breakdown
        @breakdown ||= Breakdown.new(scope.pluck(:order_nos).flatten)
      end

      def entry(load, order, raw, order_no)
        Entry.new(truck_key: truck_key(load), truck: truck(load), driver: driver(load), order: order,
                  order_no: order_no, business_date: load.business_date, load: load.label,
                  **FreightEntries.item_fields(raw), amount: raw['amount'].to_d)
      end

      def truck_key(load) = FreightEntries.truck_key(load.vehicle_id, load.carrier_id)

      def truck(load)
        return vehicle_names[load.vehicle_id] || "Vehicle #{load.vehicle_id}" if load.vehicle_id

        FreightEntries.no_truck(carrier_names[load.carrier_id] || load.carrier_id)
      end

      # Loads carry the vehicle ID only; orders carry its description ("Truck 14 Tank Wagon").
      def vehicle_names
        @vehicle_names ||= CustomerOrder.where.not(pdi_vehicle: nil).group(:pdi_vehicle_id).maximum(:pdi_vehicle)
      end

      def carrier_names
        @carrier_names ||= PdiCarrier.pluck(:pdi_carrier_id, :name).to_h
      end

      def driver(load)
        load.driver_name || load.order_nos.filter_map { |no| orders[no]&.pdi_driver }.first
      end
    end
  end
end
