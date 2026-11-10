module Reports
  class FreightByTruck < Base
    include TruckFreight

    FREIGHT_CHARGES = [PdiOrders::TruckFreight::LINE_FREIGHT, *PdiOrders::TruckFreight::SALE_FREIGHT_CODES].freeze

    report title: 'Freight by truck', area: :sales, flag: :costs,
           description: 'Freight detail rolled up per truck for orders invoiced in the period (orders with no ' \
                        'truck are grouped by carrier): per-gallon freight and charges, sale and purchase side.',
           filters: %i[dates customer_id]

    def columns
      [column(:truck, 'Truck'), column(:drivers, 'Drivers'), column(:orders, 'Orders', :number, total: true),
       column(:gallons, 'Gallons', :number, total: true),
       column(:sale_freight, 'Sale freight', :currency, total: true),
       column(:sale_charges, 'Sale charges', :currency, total: true),
       column(:sale, 'Sale total', :currency, total: true),
       column(:cost_freight, 'Purchase freight', :currency, total: true),
       column(:cost_charges, 'Purchase charges', :currency, total: true),
       column(:cost, 'Purchase total', :currency, total: true), column(:margin, 'Margin', :currency, total: true),
       column(:sale_per_gallon, 'Sale / gal', :price), column(:cost_per_gallon, 'Cost / gal', :price)]
    end

    def rows
      @rows ||= begin
        orders = freight_orders.to_a
        items = freight_items(orders).group_by(&:order)
        orders.group_by { |order| truck_sort(order) }.sort.map do |_, truck_orders|
          truck_row(truck_orders, truck_orders.flat_map { |order| items.fetch(order, []) })
        end
      end
    end

    private

    def truck_row(orders, items)
      gallons = orders.sum { |o| o.pdi_gallons.to_d }
      sale = split(items, :sale)
      cost = split(items, :cost)
      { **truck_columns(orders), gallons: gallons.round, **side_columns(:sale, sale), **side_columns(:cost, cost),
                                 margin: sale.sum - cost.sum, **per_gallon(sale.sum, cost.sum, gallons) }
    end

    def truck_columns(orders)
      { truck: truck_name(orders.max_by(&:invoice_date)), drivers: drivers(orders), orders: orders.size }
    end

    def side_columns(side, (freight, charges))
      { "#{side}_freight": freight, "#{side}_charges": charges, side => freight + charges }
    end

    # [per-gallon / line freight, charges] for one side.
    def split(items, side)
      freight, charges = items.partition { |item| FREIGHT_CHARGES.include?(item.charge) }
      [freight.sum(0, &side), charges.sum(0, &side)]
    end

    # Most deliveries first.
    def drivers(orders)
      orders.filter_map(&:pdi_driver).tally.sort_by { |_, n| -n }.map(&:first).join(', ')
    end
  end
end
