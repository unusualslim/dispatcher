module Reports
  class FreightByTruck < Base
    report title: 'Freight by truck', area: :sales, flag: :costs,
           description: 'Freight detail rolled up per truck (no truck = grouped by carrier): per-gallon freight and ' \
                        'charges, sale and purchase side, by invoice date or load business date.',
           filters: %i[dates date_basis carrier_id customer_id]

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
        source = FreightEntries.for(filters)
        entries = source.entries.group_by(&:truck_key)
        hauls = source.hauls.group_by(&:truck_key)
        (entries.keys | hauls.keys).sort.map { |key| truck_row(hauls.fetch(key, []), entries.fetch(key, [])) }
      end
    end

    private

    def truck_row(hauls, entries)
      gallons = hauls.sum(0.to_d, &:gallons)
      sale = split(entries, :sale)
      cost = split(entries, :cost)
      totals = { gallons: gallons.round, margin: sale.sum - cost.sum }
      truck_columns(hauls + entries).merge(totals, side_columns(:sale, sale), side_columns(:cost, cost),
                                           per_gallon(sale.sum, cost.sum, gallons))
    end

    def truck_columns(rows)
      { truck: rows.first.truck, drivers: drivers(rows), orders: rows.filter_map(&:order_no).uniq.size }
    end

    def side_columns(side, (freight, charges))
      { "#{side}_freight": freight, "#{side}_charges": charges, side => freight + charges }
    end

    # [per-gallon / line freight, charges] for one side.
    def split(entries, side)
      freight, charges = entries.partition(&:freight?)
      [freight.sum(0, &side), charges.sum(0, &side)]
    end

    def per_gallon(sale, cost, gallons)
      return {} unless gallons.positive?

      { sale_per_gallon: (sale / gallons).round(4), cost_per_gallon: (cost / gallons).round(4) }
    end

    # Most lines first.
    def drivers(rows)
      rows.filter_map(&:driver).tally.sort_by { |_, n| -n }.map(&:first).join(', ')
    end
  end
end
