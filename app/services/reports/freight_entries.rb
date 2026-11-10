module Reports
  # The freight lines behind Freight detail and Freight by truck, on one of two date bases:
  # - invoice: PDI orders invoiced in the period, with the freight items PDI put on each order
  #   (FreightEntries::ByInvoice)
  # - business: PDI fuel loads with a business date in the period, as PDI's FI Fuel Delivery Report: purchase
  #   freight from the load, sale freight from its orders (FreightEntries::ByLoad)
  module FreightEntries
    BASES = { 'Invoice date' => 'invoice', 'Load business date' => 'business' }.freeze
    NO_TRUCK = 'No truck'.freeze
    FREIGHT_CHARGES = [PdiOrders::TruckFreight::LINE_FREIGHT, *PdiOrders::TruckFreight::SALE_FREIGHT_CODES].freeze

    # One freight amount. truck_key sorts trucks by number, then the no-truck carriers.
    Entry = Struct.new(:truck_key, :truck, :driver, :business_date, :order, :order_no, :load, :bol, :side, :charge,
                       :product, :quantity, :rate, :amount, keyword_init: true) do
      def sale = side == 'sale' ? amount : 0
      def cost = side == 'purchase' ? amount : 0
      def freight? = FREIGHT_CHARGES.include?(charge)
    end

    # Gallons hauled on one order, for the per-truck totals.
    Haul = Struct.new(:truck_key, :truck, :driver, :order_no, :gallons, keyword_init: true)

    def self.for(filters)
      (filters[:date_basis] == 'business' ? ByLoad : ByInvoice).new(filters)
    end

    # The Entry fields a stored freight item carries (amount aside).
    def self.item_fields(raw)
      { bol: raw['bol'], side: raw['side'], charge: raw['charge'], product: raw['product'],
        quantity: raw['quantity']&.to_d, rate: raw['rate']&.to_d }
    end

    def self.truck_key(vehicle_id, carrier_id)
      vehicle_id ? [0, vehicle_id.to_i, vehicle_id.to_s] : [1, 0, carrier_id.to_s]
    end

    def self.no_truck(carrier_name)
      "#{NO_TRUCK} (#{carrier_name || 'no carrier'})"
    end
  end
end
