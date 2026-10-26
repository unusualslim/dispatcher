require 'net/http'

# Client for PDI's Enterprise Web Service (SOAP, PDIEnterpriseWeb.asmx).
# Every call authenticates with a UserCredentials header (web partner ID + password).
# Results come back as XML inside <OperationResult>; PDI reports its own errors as a
# PDIExceptionMessage there (HTTP 200), and crashes as a SOAP fault (HTTP 500).
class PdiWebService
  class Error < StandardError; end
  class NotConfigured < Error; end

  # What a failed call can raise: PDI's own errors and network trouble.
  FAILURES = [Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError].freeze

  NAMESPACE = 'http://profdata.com.Petronet'.freeze
  DEFAULT_URL = 'https://account.fivepointsservice.com/PDIEnterpriseWeb.asmx'.freeze

  # CreditStatus 0 = OK, 1 = Credit Hold (checked against PDI's order screen).
  CreditCheck = Struct.new(:credit_status, :available_credit, :credit_limit, :hold_credit_limit,
                           :account_status, keyword_init: true) do
    def on_hold?
      credit_status != 0
    end
  end

  def self.configured?
    ENV['PDI_API_PARTNER_ID'].present? && ENV['PDI_API_PASSWORD'].present?
  end

  def initialize(read_timeout: 120)
    unless self.class.configured?
      raise NotConfigured, 'PDI web service credentials are not set (PDI_API_PARTNER_ID / PDI_API_PASSWORD)'
    end

    @uri = URI(ENV.fetch('PDI_API_URL', DEFAULT_URL))
    @read_timeout = read_timeout
  end

  # Full PDI master file (customers + ship-tos, terminals, sites, products, carriers…) as an XML string.
  # PDI's test tool labels mode 0 "All" and 1 "New / Changed".
  def master_data(mode: 0)
    call('GetMasterData', "<mode>#{Integer(mode)}</mode>").to_xml
  end

  def credit_check(customer_id, additional_amount = 0)
    node = call('CustomerCreditCheck',
                "<CustomerID>#{escape(customer_id)}</CustomerID>" \
                "<AdditionalChargeAmount>#{escape(additional_amount)}</AdditionalChargeAmount>")
    CreditCheck.new(
      credit_status: node.at('CreditStatus').text.to_i, account_status: node.at('AccountStatus').text.to_i,
      available_credit: decimal(node, 'AvailableCredit'), credit_limit: decimal(node, 'StatedCreditLimit'),
      hold_credit_limit: decimal(node, 'HoldCreditLimit')
    )
  end

  # PDI's numeric order status (1 = Open; 99 comes back for unknown order numbers).
  def order_status(order_no)
    call('GetOrderStatus', "<OrderNo>#{escape(order_no)}</OrderNo>").at('Status')&.text&.to_i
  end

  # <PDIWarehouseOrders> with one <PDIWarehouseOrder> per order. Warehouse orders carry no status,
  # so callers ask for one status code at a time. Dates filter on the scheduled delivery date.
  # Each order arrives once (see OrderFilter), so save whatever comes back.
  def warehouse_orders(**filter)
    call('GetWarehouseOrders', OrderFilter.xml('PDIGetWarehouseOrders', **filter))
  end

  # <PDIFuelOrders> with one <PDIFuelOrder> (including <OrderStatus>) per order.
  def fuel_orders(**filter)
    call('GetFuelOrders', OrderFilter.xml('PDIGetFuelOrders', **filter))
  end

  # Posts one SOAP operation and returns the result's root element (namespaces removed).
  def call(operation, body_xml)
    request = Net::HTTP::Post.new(@uri, 'Content-Type' => 'text/xml; charset=utf-8',
                                        'SOAPAction' => %("#{NAMESPACE}/#{operation}"))
    request.body = envelope(operation, body_xml)
    response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == 'https',
                                                     open_timeout: 15, read_timeout: @read_timeout) do |http|
      http.request(request)
    end
    parse(operation, response)
  end

  private

  def envelope(operation, body_xml)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header>
          <UserCredentials xmlns="#{NAMESPACE}">
            <Password>#{escape(ENV.fetch('PDI_API_PASSWORD'))}</Password>
            <PartnerID>#{escape(ENV.fetch('PDI_API_PARTNER_ID'))}</PartnerID>
          </UserCredentials>
        </soap:Header>
        <soap:Body>
          <#{operation} xmlns="#{NAMESPACE}">#{body_xml}</#{operation}>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  def parse(operation, response)
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    check_response!(operation, doc, response)

    root = result_root(doc.at("#{operation}Result"))
    raise Error, "#{operation}: empty response" unless root

    exception = root.at('PDIExceptionMessage')
    raise Error, "#{operation}: #{exception.at('Description')&.text}" if exception

    root
  end

  def check_response!(operation, doc, response)
    fault = doc.at('Fault faultstring')
    raise Error, "#{operation}: #{fault.text}" if fault
    raise Error, "#{operation}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end

  # The result is usually child elements, but an escaped XML string is handled too.
  def result_root(result)
    return unless result

    result.element_children.first || Nokogiri::XML(result.text).tap(&:remove_namespaces!).root
  end

  def decimal(node, name)
    node.at(name)&.text&.to_d
  end

  def escape(value)
    ERB::Util.html_escape(value.to_s)
  end
end
