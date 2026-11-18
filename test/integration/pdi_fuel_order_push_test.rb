require 'test_helper'
require 'minitest/mock'

# Send to PDI: an app order goes to PDI as a fuel order, PDI prices it, and the order sync links it back.
class PdiFuelOrderPushTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Stands in for PdiWebService: records what was sent and answers like PDI.
  class FakePdi
    attr_reader :sent, :recalculated

    def initialize(reply)
      @reply = reply
      @recalculated = []
    end

    def add_fuel_order(xml, target_status:)
      @sent = [xml, target_status]
      @reply
    end

    def recalculate_order(order_no) = @recalculated << order_no
    def responses(_ids) = '<Response><OrderNo>OD-777-26</OrderNo></Response>'
  end

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    ReportingGroup.find_or_create_by!(name: 'DEF-Fuel') { |g| g.item_type = 'fuel' }
    @def = Product.find_by(id: '901') || Product.create!(id: '901', name: 'Bulk DEF')
    @def.update!(category: 'DEF-Fuel')
    @customer = Customer.create!(name: 'Sumter Farms', pdi_customer_id: '1082', po_required: true,
                                 preferred_contact_method: 'no preference')
    @site = Location.create!(company_name: 'Farm Shop', location_category_id: 2)
    CustomerLocation.create!(customer: @customer, location: @site, pdi_location_id: '10')
    @order = CustomerOrder.create!(customer: @customer, location: @site, required_delivery_date: Date.new(2026, 11, 20),
                                   delivery_time: '09:30', order_date: Date.new(2026, 11, 18), notes: 'Gate code 1234')
    @order.customer_order_products.create!(product: @def, quantity: 2500)
    @user = User.create!(email: 'pdi-push@example.com', password: 'password123', role: 'admin')
  end

  test 'the checklist names what is missing; the XML carries only the main information' do
    push = PdiOrders::FuelOrderPush.new(@order)
    assert_equal ['This customer requires a PO number'], push.problems
    @order.update!(customer_po_number: 'P6153')
    assert push.ready?

    xml = Nokogiri::XML(push.xml).tap(&:remove_namespaces!)
    assert_equal [['1', '1082', '10', 'P6153', "APP#{@order.id}", '2026-11-20T09:30:00', '2026-11-18', '1514']],
                 [%w[DestinationType CustomerID CustomerLocationID PurchaseOrderNo AlternateReferenceNo DeliveryDateTime
                     BusinessDate CarrierID].map { |name| xml.at("PDIFuelOrder > #{name}").text }]
    line = xml.at('FuelDetail')
    assert_equal(%w[1 901 901 2500.0 0 0], %w[OrderLineItemNo OrderedProductID PurchasedProductID OrderedQuantity
                                              UnitPrice UnitPriceOverridden].map { |n| line.at(n).text })
    assert_nil xml.at('DestinationTankID')
  end

  test 'Send to PDI links the order number PDI returns and has PDI price it' do
    @order.update!(customer_po_number: 'P6153')
    fake = FakePdi.new('<PDIFuelOrders><PDIFuelOrder><OrderNo>OD-123-26</OrderNo></PDIFuelOrder></PDIFuelOrders>')
    sign_in @user
    with_pdi(fake) { post send_to_pdi_customer_order_path(@order) }

    assert_redirected_to customer_order_path(@order)
    @order.reload
    assert_equal %w[OD-123-26 sent open_order],
                 [@order.external_order_no, @order.pdi_push_status, @order.order_status]
    assert_equal ['OD-123-26'], fake.recalculated
    assert_equal 1, fake.sent.last
    assert_includes PdiOrders::FuelOrderPush.new(@order).problems, 'Already sent to PDI'
  end

  test 'a queued push is checked later, or linked by the order sync through our reference' do
    @order.update!(customer_po_number: 'P6153')
    PdiOrders::FuelOrderPush.new(@order).push!(user: @user,
                                               service: FakePdi.new('1b4e28ba-2fa1-11d2-883f-0016d3cca427'))
    assert_equal %w[queued 1b4e28ba-2fa1-11d2-883f-0016d3cca427], [@order.pdi_push_status, @order.pdi_request_id]

    feed = Nokogiri::XML(<<~XML).root
      <PDIFuelOrder><OrderNo>OD-555-26</OrderNo><OrderStatus>1</OrderStatus><DestinationType>1</DestinationType>
        <CustomerID>1082</CustomerID><CustomerLocationID>10</CustomerLocationID><AlternateReferenceNo>APP#{@order.id}</AlternateReferenceNo>
        <DeliveryDateTime>2026-11-20T09:30:00</DeliveryDateTime><BusinessDate>2026-11-18</BusinessDate>
        <FuelDetail><OrderLineItemNo>1</OrderLineItemNo><OrderedProductID>901</OrderedProductID>
          <OrderedQuantity>2500</OrderedQuantity><UnitPrice>2.60</UnitPrice><DestinationTankID>T1</DestinationTankID></FuelDetail>
      </PDIFuelOrder>
    XML
    assert_no_difference('CustomerOrder.count') { PdiOrders::OrderWriter.new(PdiOrders::OrderNode.new(feed)).save! }
    @order.reload
    assert_equal %w[OD-555-26 sent], [@order.external_order_no, @order.pdi_push_status]
    assert_in_delta 2.6, @order.customer_order_products.first.price.to_f
  end

  test 'the order page shows the checklist, and an order PDI sent is left alone' do
    sign_in @user
    patch customer_order_path(@order),
          params: { customer_order: { customer_po_number: 'P77', release_number: 'R-4410' } }
    assert_equal %w[P77 R-4410], [@order.reload.customer_po_number, @order.release_number]
    @order.update!(customer_po_number: nil)
    get customer_order_path(@order)
    assert_select 'div', text: 'R-4410'
    assert_select '.card-body li', text: 'This customer requires a PO number'

    pdi_order = CustomerOrder.create!(customer: @customer, location: @site, external_order_no: 'OD-9-26')
    get customer_order_path(pdi_order)
    assert_select '.card-header span', text: 'PDI', count: 0
  end

  private

  def with_pdi(fake, &)
    PdiWebService.stub(:new, fake) { PdiWebService.stub(:configured?, true, &) }
  end
end
