require 'test_helper'

# Which carrier an order's freight is priced for.
class OrderFreightTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    site = Location.create!(company_name: 'Ofr Site', location_category_id: 2)
    @order = CustomerOrder.create!(location: site, order_status: 'open_order')
    Vendor.find_or_create_by!(id: '1512') { |v| v.name = 'Five Points Service, Inc.' }
    @outside = Vendor.create!(id: 'OFR-OUT', name: 'Ofr Outside Carrier')
  end

  test "an app order is carried by Five Points Logistics; its dispatch's vendor is not a carrier" do
    assert_equal '1514', @order.freight_carrier_vendor_id

    dispatch = Dispatch.create!(vendor_id: @outside.id)
    dispatch.customer_orders << @order
    assert_equal '1514', @order.reload.freight_carrier_vendor_id
  end

  test "PDI's carrier and a carrier set on the order come first" do
    @order.update!(external_order_no: 'OFR-1', pdi_carrier_id: '6140')
    assert_equal '6140', @order.freight_carrier_vendor_id
    @order.update!(freight_carrier_id: @outside.id)
    assert_equal @outside.id, @order.freight_carrier_vendor_id
  end

  test 'a PDI order without a carrier has none' do
    @order.update!(external_order_no: 'OFR-2')
    assert_nil @order.freight_carrier_vendor_id
  end
end
