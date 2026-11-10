module PdiOrders
  # The truck, driver and freight items on one PDI order, as CustomerOrder pdi_* attributes (Reports::FreightDetail).
  # One item per freight amount, side sale or purchase:
  # - "Freight" per gallon on fuel lines: sale = FreightUnitPrice × delivered gallons, purchase = each load's
  #   FreightUnitCost × lifted gallons
  # - FREIGHT / DELIVERY lines on warehouse orders (sale)
  # - PDI's freight charges by their ID (FPLSPLIT, OWIFSC…): a PurchaseSideKey charge belongs to the load and
  #   repeats on each of its orders, so it keeps the key ("load") for the report to split; SaleSideKey or
  #   "applies to the order only" charges are the order's own sale charge.
  # Zero amounts are left out.
  class TruckFreight
    SALE_FREIGHT_CODES = %w[FREIGHT DELIVERY].freeze
    LINE_FREIGHT = 'Freight'.freeze

    def initialize(node)
      @node = node
    end

    def attrs
      { pdi_vehicle_id: text('VehicleID'), pdi_vehicle: text('VehicleDescription'), pdi_driver: text('DriverName'),
        pdi_gallons: fuel_lines.sum { |line| delivered(line) }.round(2), pdi_freight_items: items }
    end

    def items
      (fuel_sales + fuel_costs + freight_lines + charges).reject { |item| item['amount'].to_d.zero? }
    end

    private

    def fuel_lines = @node.xpath('FuelDetail')

    def fuel_sales
      fuel_lines.map do |line|
        item('sale', LINE_FREIGHT, product: product(line), quantity: delivered(line),
                                   rate: number(line, 'FreightUnitPrice'))
      end
    end

    def fuel_costs
      fuel_lines.flat_map do |line|
        line.xpath('LoadDetail').map do |load|
          item('purchase', LINE_FREIGHT, product: product(line), quantity: lifted(load),
                                         rate: number(load, 'FreightUnitCost'), bol: text('BOLNo', load))
        end
      end
    end

    def freight_lines
      @node.xpath('WarehouseDetail|NonInvDetail').filter_map do |line|
        code = text('OrderedProductID', line).to_s.upcase
        next unless SALE_FREIGHT_CODES.include?(code)

        item('sale', code, quantity: number(line, 'OrderedQuantity'), rate: number(line, 'UnitPrice'))
      end
    end

    def charges
      @node.xpath('PerLoadCharge').map do |node|
        load = text('PurchaseSideKey', node)
        sale = load.nil? && (text('SaleSideKey', node).present? || text('FreightChargeAppliesTo', node) == '2')
        item(sale ? 'sale' : 'purchase', text('FreightChargeID', node), amount: number(node, 'FreightChargeAmount'),
                                                                        load: load)
      end
    end

    def item(side, charge, amount: nil, **extra)
      quantity = extra.delete(:quantity)
      rate = extra.delete(:rate)
      amount ||= (quantity * rate).round(2)
      { 'side' => side, 'charge' => charge, 'quantity' => quantity&.to_s('F'), 'rate' => rate&.to_s('F'),
        'amount' => amount.to_s('F'), **extra.compact.transform_keys(&:to_s) }
    end

    # Fuel lines name the product loaded (PurchasedProductID) and the one ordered.
    def product(line) = text('PurchasedProductID', line) || text('OrderedProductID', line)

    def delivered(line) = nonzero(line, 'DeliveredNetQuantity') || number(line, 'OrderedQuantity')
    def lifted(load) = nonzero(load, 'LiftNetQuantity') || number(load, 'LoadQuantity')

    def nonzero(node, path)
      value = number(node, path)
      value unless value.zero?
    end

    def number(node, path) = text(path, node).to_d

    def text(path, node = @node)
      node.at_xpath(path)&.text&.strip.presence
    end
  end
end
