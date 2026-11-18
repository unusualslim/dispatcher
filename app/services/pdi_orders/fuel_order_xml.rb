module PdiOrders
  # The <PDIFuelOrders xmlns=""> document for Send to PDI (PDIFuelOrders.xsd), elements in the schema's order:
  # the main information only, prices as 0 "not overridden" so PDI prices the order.
  class FuelOrderXml
    DESTINATION_CUSTOMER = 1
    DEFAULT_CARRIER = '1514'.freeze # Five Points Logistics: our own trucks
    COMPANY_BULK_PLANT = 1 # LoadDetail OriginType (0 = vendor/terminal)
    ZERO_PRICES = { 'DeliveredGrossQuantity' => 0, 'DeliveredNetQuantity' => 0, 'UnitPrice' => 0,
                    'UnitPriceOverridden' => 0, 'FreightUnitPrice' => 0, 'FreightUnitPriceOverridden' => 0 }.freeze

    def initialize(order, lines:, ship_to_id:, reference:)
      @order = order
      @lines = lines
      @ship_to_id = ship_to_id
      @reference = reference
    end

    def to_xml
      Nokogiri::XML::Builder.new do |x|
        x.PDIFuelOrders(xmlns: '') do
          x.PDIFuelOrder do
            elements(x, header)
            @lines.each_with_index { |line, i| fuel_detail(x, line, i + 1) }
          end
        end
      end.doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    private

    def fuel_detail(xml, line, number)
      xml.FuelDetail do
        elements(xml, detail(line, number))
        xml.LoadDetail { elements(xml, load_detail(line)) }
      end
    end

    def elements(xml, fields)
      fields.compact.each { |name, value| xml.send(name, value) }
    end

    # [element, value] in schema order; nil entries are left out.
    def header
      [['DestinationType', DESTINATION_CUSTOMER], ['CustomerID', @order.customer.pdi_customer_id],
       ['CustomerLocationID', @ship_to_id], (['PurchaseOrderNo', @order.customer_po_number] if po?),
       ['AlternateReferenceNo', @reference], ['DeliveryDateTime', delivery_time],
       ['BusinessDate', (@order.order_date || Date.current).to_date.iso8601],
       ['CarrierID', @order.pdi_carrier_id.presence || DEFAULT_CARRIER], notes]
    end

    def detail(line, number)
      [['OrderLineItemNo', number], ['OrderedProductID', line.product_id], ['PurchasedProductID', line.product_id],
       ['OrderedQuantity', line.quantity.to_d.to_s('F')], *ZERO_PRICES.to_a]
    end

    # PDI requires a load on each fuel line: planned from the order's ship-from site (else the main plant, site 2) as
    # a company-owned bulk plant, nothing lifted and no cost yet. The real load (terminal, BOL, gallons) is recorded
    # in PDI.
    def load_detail(line)
      [['LoadProductID', line.product_id], ['LoadQuantity', line.quantity.to_d.round(2).to_s('F')],
       ['LiftGrossQuantity', 0], ['LiftNetQuantity', 0], ['OriginType', COMPANY_BULK_PLANT],
       ['OriginSiteID', origin_site], ['UnitCost', 0], ['UnitCostOverridden', 0], ['FreightUnitCost', 0],
       ['FreightUnitCostOverridden', 0]]
    end

    # PDI's site number (no leading zeros) of the ship-from warehouse, else the main plant.
    def origin_site
      code = @order.ship_from_location&.pdi_site_code.presence || PdiOrders::Warehouses::MAIN_SITE
      code.sub(/\A0+(?=\d)/, '')
    end

    def po? = @order.customer_po_number.present?

    def notes
      ['OrderNotes', @order.notes.to_s.squish.truncate(255)] if @order.notes.present?
    end

    # PDI's local date and time, no zone (as its own feed sends them); midnight when no time was entered.
    def delivery_time
      time = @order.delivery_time
      format('%<date>sT%<h>02d:%<m>02d:00', date: @order.required_delivery_date.iso8601, h: time&.hour.to_i,
                                            m: time&.min.to_i)
    end
  end
end
