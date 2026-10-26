module PdiOrders
  # One <PDIWarehouseOrder> or <PDIFuelOrder> from the feed, read as CustomerOrder attributes.
  class OrderNode
    LINES = 'FuelDetail|WarehouseDetail|NonInvDetail'.freeze

    Line = Struct.new(:product_code, :quantity, :price, keyword_init: true)

    # batch_status: the status a warehouse order was fetched with (fuel orders carry their own).
    def initialize(node, batch_status = nil)
      @node = node
      @batch_status = batch_status
    end

    def order_no = text('OrderNo')
    def customer_id = text('CustomerID')
    def customer_name = text('CustomerDescription')
    def ship_to_id = text('CustomerLocationID')
    def site_id = text('SiteID')
    def carrier_id = text('CarrierID')

    # DestinationType 0 = one of our own sites (tank wagon plant, bulk plant): no customer.
    def site? = text('DestinationType') == '0'

    def status_code
      Integer(text('OrderStatus') || @batch_status)
    end

    # Invoice no. only arrives once billed; salesperson, invoice date and carrier name aren't in the API.
    def attrs
      { external_order_no: order_no, order_status: Statuses.enum_key(status_code),
        odor_status: Statuses.name(status_code), order_date: time('OrderEntryDateTime') || time('BusinessDate'),
        required_delivery_date: time('DeliveryDateTime')&.to_date || time('ScheduledDateTime')&.to_date,
        invoice_no: text('InvoiceNo'), pdi_carrier_id: carrier_id }.compact
    end

    # The customer's credit as PDI reported it with this order.
    def credit
      return {} unless text('CreditStatus')

      { pdi_credit_status: text('CreditStatus'), pdi_credit_limit: text('CreditLimit')&.to_d,
        pdi_available_credit: text('TotalAvailableCredit')&.to_d }
    end

    def ship_to
      { company_name: text('ShipToDescription'), city: text('ShipToCity'), state: text('ShipToState'),
        zip: text('ShipToPostalCode'), phone_number: text('ShipToPhone'),
        address: [text('ShipToAddress1'), text('ShipToAddress2')].compact.join(', ').presence }.compact
    end

    def lines
      @node.xpath(LINES).map do |line|
        Line.new(product_code: product_code(line), quantity: text('OrderedQuantity', line).to_d.round,
                 price: text('UnitPrice', line)&.to_d)
      end
    end

    private

    # Fuel lines name the product ordered and the one actually loaded: ordered 10011219 "Bulk DEF" is
    # loaded as 901. The loaded (purchased) product is the real one, except on blends, where it's the
    # blend ID (ordered 901 → purchased 901B).
    def product_code(line)
      purchased = text('PurchasedProductID', line)
      return text('OrderedProductID', line) if purchased.nil? || text('ProductBlendID', line)

      purchased
    end

    def text(path, node = @node)
      node.at_xpath(path)&.text&.strip.presence
    end

    def time(path)
      value = text(path)
      Time.zone.parse(value) if value
    end
  end
end
