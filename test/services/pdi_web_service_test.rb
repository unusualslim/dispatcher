require 'test_helper'
require 'minitest/mock'

class PdiWebServiceTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h.slice('PDI_API_PARTNER_ID', 'PDI_API_PASSWORD', 'PDI_API_URL')
    ENV['PDI_API_PARTNER_ID'] = 'team.test'
    ENV['PDI_API_PASSWORD'] = 'p&ss<word>'
    ENV['PDI_API_URL'] = 'https://pdi.example.com/PDIEnterpriseWeb.asmx'
  end

  teardown do
    %w[PDI_API_PARTNER_ID PDI_API_PASSWORD PDI_API_URL].each { |k| ENV[k] = @env[k] }
  end

  def soap(operation, inner)
    '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' \
      "<soap:Body><#{operation}Response xmlns=\"http://profdata.com.Petronet\"><#{operation}Result>#{inner}" \
      "</#{operation}Result></#{operation}Response></soap:Body></soap:Envelope>"
  end

  def http_response(body, klass: Net::HTTPOK, code: '200')
    klass.new('1.1', code, 'OK').tap do |response|
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end

  # Stubs the HTTP round trip and captures the request.
  def with_response(response, &)
    captured = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |req|
      captured = req
      response
    end
    Net::HTTP.stub(:start, ->(*_args, **_opts, &session) { session.call(fake_http) }, &)
    captured
  end

  test 'credit check parses the response and escapes credentials' do
    body = soap('CustomerCreditCheck',
                '<PDICustomerCreditCheckResponse><Result>0</Result><CreditStatus>1</CreditStatus>' \
                '<AvailableCredit>-53727.98</AvailableCredit><StatedCreditLimit>250000.00</StatedCreditLimit>' \
                '<HoldCreditLimit>250000.00</HoldCreditLimit><AccountStatus>0</AccountStatus>' \
                '</PDICustomerCreditCheckResponse>')
    credit = nil
    request = with_response(http_response(body)) { credit = PdiWebService.new.credit_check('2362') }

    assert credit.on_hold?
    assert_equal BigDecimal('-53727.98'), credit.available_credit
    assert_equal BigDecimal('250000'), credit.credit_limit
    assert_equal '"http://profdata.com.Petronet/CustomerCreditCheck"', request['SOAPAction']
    assert_includes request.body, '<Password>p&amp;ss&lt;word&gt;</Password>'
    assert_includes request.body, '<CustomerID>2362</CustomerID>'
  end

  test 'order status returns the numeric code' do
    body = soap('GetOrderStatus',
                '<PDIOrderStatusResponse><OrderNo>OD-050103-26</OrderNo><Status>1</Status></PDIOrderStatusResponse>')
    status = nil
    with_response(http_response(body)) { status = PdiWebService.new.order_status('OD-050103-26') }

    assert_equal 1, status
  end

  test 'raises PDI exception messages and SOAP faults' do
    body = soap('GetMasterData', '<PDIGetMasterDataResponse><PDIExceptionMessage><Type>1</Type>' \
                                 '<Description>Web partner does not have an OD web service profile.</Description>' \
                                 '</PDIExceptionMessage></PDIGetMasterDataResponse>')
    error = assert_raises(PdiWebService::Error) { with_response(http_response(body)) { PdiWebService.new.master_data } }
    assert_match(/does not have an OD web service profile/, error.message)

    fault = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><soap:Fault>' \
            '<faultcode>soap:Server</faultcode><faultstring>Object reference not set</faultstring>' \
            '</soap:Fault></soap:Body></soap:Envelope>'
    response = http_response(fault, klass: Net::HTTPInternalServerError, code: '500')
    error = assert_raises(PdiWebService::Error) { with_response(response) { PdiWebService.new.order_status('1') } }
    assert_match(/Object reference not set/, error.message)
  end

  test 'requires credentials' do
    ENV['PDI_API_PASSWORD'] = nil
    assert_not PdiWebService.configured?
    assert_raises(PdiWebService::NotConfigured) { PdiWebService.new }
  end
end
