module PdiFuelLoads
  # One <PDIFuelLoad> as PdiFuelLoad attributes. Purchase freight per load line = FreightUnitCost × lifted net
  # gallons, rounded per line like PDI; per-load charges sit on the load once.
  class LoadNode
    def initialize(node)
      @node = node
    end

    def attrs
      { load_no: text('LoadNo'), load_reference_no: text('LoadReferenceNo'), business_date: text('BusinessDate'),
        lift_date: text('LiftDateTime')&.slice(0, 10), carrier_id: text('CarrierID'), vehicle_id: text('VehicleID'),
        driver_name: text('DriverName'), order_nos: orders.map { |order| text('OrderNo', order) }.compact.uniq,
        items: lines + charges }
    end

    private

    def orders = @node.xpath('PDIFuelOrder')

    def lines
      orders.flat_map do |order|
        order.xpath('FuelDetail').flat_map do |detail|
          detail.xpath('LoadDetail').map { |load| line(order, detail, load) }
        end
      end
    end

    def line(order, detail, load)
      quantity = number(load, 'LiftNetQuantity')
      quantity = number(load, 'LoadQuantity') if quantity.zero?
      rate = number(load, 'FreightUnitCost')
      { 'charge' => PdiOrders::TruckFreight::LINE_FREIGHT, 'order_no' => text('OrderNo', order),
        'bol' => text('BOLNo', load), 'product' => text('LoadProductID', load) || text('PurchasedProductID', detail),
        'quantity' => quantity.to_s('F'), 'rate' => rate.to_s('F'), 'amount' => (quantity * rate).round(2).to_s('F') }
    end

    def charges
      @node.xpath('PerLoadCharge').map do |charge|
        { 'charge' => text('FreightChargeID', charge), 'amount' => number(charge, 'FreightChargeAmount').to_s('F') }
      end
    end

    def number(node, path) = text(path, node).to_d

    def text(path, node = @node)
      node.at_xpath(path)&.text&.strip.presence
    end
  end
end
