require 'test_helper'

class PdiOrderApiImportServiceTest < ActiveSupport::TestCase
  def feed
    file_fixture('pdi_orders.xml').read
  end

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  test 'imports warehouse, fuel and own-site orders with their PDI statuses and lines' do
    result = PdiOrderApiImportService.call(feed)

    assert_equal [3, 0, 0, []], [result.created, result.updated, result.unchanged, result.errors]
    warehouse = CustomerOrder.find_by!(external_order_no: 'OD-050103-26')
    assert_equal ['open_order', 'Open Order'], [warehouse.order_status, warehouse.odor_status]
    assert_equal Date.new(2026, 10, 9), warehouse.required_delivery_date
    assert_equal([['BF0130', 1452, BigDecimal('46.75')]],
                 warehouse.customer_order_products.map { |l| [l.product_name, l.quantity, l.price] })

    spc = Customer.find_by!(pdi_customer_id: '2362')
    assert_equal spc, warehouse.customer
    assert_equal warehouse.location, CustomerLocation.find_by!(customer: spc, pdi_location_id: '12').location
    assert_equal ['1605 Lake Street', 'Melbourne', '32901'],
                 [warehouse.location.address, warehouse.location.city, warehouse.location.zip]

    fuel = CustomerOrder.find_by!(external_order_no: 'OD-051313-26')
    assert_equal 'dispatched', fuel.order_status
    assert_equal %w[101 901 901 FRT], fuel.customer_order_products.order(:product_name).pluck(:product_name),
                 'loaded product (901), not ordered 10011219; a blend keeps its ordered product'

    site = CustomerOrder.find_by!(external_order_no: 'OD-050878-26')
    assert_equal ['billed', 'OD-050878-26', nil], [site.order_status, site.invoice_no, site.customer]
    assert_equal 'Tank Wagon Bulk Plant', site.location.company_name
  end

  test 'a second import changes nothing; a changed status or line updates the order' do
    PdiOrderApiImportService.call(feed)
    again = PdiOrderApiImportService.call(feed)
    assert_equal [0, 0, 3], [again.created, again.updated, again.unchanged]

    changed = feed.sub('<OrderStatus>4</OrderStatus>', '<OrderStatus>10</OrderStatus>')
                  .sub('<OrderedQuantity>1452.0000</OrderedQuantity>', '<OrderedQuantity>1500.0000</OrderedQuantity>')
    result = PdiOrderApiImportService.call(changed)

    assert_equal [0, 2, 1], [result.created, result.updated, result.unchanged]
    assert_equal 'released_for_dispatch', CustomerOrder.find_by!(external_order_no: 'OD-051313-26').order_status
    assert_equal [1500],
                 CustomerOrder.find_by!(external_order_no: 'OD-050103-26').customer_order_products.pluck(:quantity)
  end

  test 'uses linked customers and ship-tos, and keeps the location of an order the FTP import created' do
    spc = Customer.create!(name: 'Southern Performance Chemical', preferred_contact_method: 'no preference')
    ftp_location = Location.create!(company_name: '12 - Southern Performance Chemical', location_category_id: 2)
    CustomerOrder.create!(external_order_no: 'OD-050103-26', customer: spc, location: ftp_location,
                          order_status: 'open_order')
    sumter = Customer.create!(name: 'Sumter Farms', pdi_customer_id: '1082', preferred_contact_method: 'no preference')
    farm = Location.create!(company_name: 'Sumter Farm Shop', location_category_id: 2)
    CustomerLocation.create!(customer: sumter, location: farm, pdi_location_id: '10')

    assert_no_difference -> { Customer.count } do
      PdiOrderApiImportService.call(feed)
    end

    assert_equal '2362', spc.reload.pdi_customer_id, 'linked by name'
    assert_equal ftp_location, CustomerOrder.find_by!(external_order_no: 'OD-050103-26').location
    assert_equal '12', CustomerLocation.find_by!(customer: spc, location: ftp_location).pdi_location_id
    assert_equal farm, CustomerOrder.find_by!(external_order_no: 'OD-051313-26').location
  end

  test 'one bad order is reported and the rest import' do
    result = PdiOrderApiImportService.call(feed.sub('<OrderStatus>4</OrderStatus>', '<OrderStatus>42</OrderStatus>'))

    assert_equal 2, result.created
    assert_match(/OD-051313-26: unknown PDI order status 42/, result.errors.join)
  end

  test 'keeps PDI credit and adjustment lines with negative prices' do
    adjustment = '<NonInvDetail><OrderedProductID>ITEM</OrderedProductID><OrderedQuantity>1.0000</OrderedQuantity>' \
                 '<UnitPrice>-0.0100000</UnitPrice></NonInvDetail></PDIFuelOrder>'
    result = PdiOrderApiImportService.call(feed.sub(%r{</FuelDetail>\s*</PDIFuelOrder>}, "</FuelDetail>#{adjustment}"))

    assert_empty result.errors
    lines = CustomerOrder.find_by!(external_order_no: 'OD-050878-26').customer_order_products
    assert_includes lines.map(&:price), BigDecimal('-0.01')
  end

  test 'fuel and non-inventory products do not need production; manufactured goods do' do
    ReportingGroup.find_or_create_by!(name: 'DEF-Fuel') { |g| g.item_type = 'fuel' }
    ReportingGroup.find_or_create_by!(name: 'DEF') { |g| g.item_type = 'warehouse' }
    Product.where(id: %w[901 DEF25]).delete_all
    Product.create!(id: '901', name: 'Diesel Exhaust Fluid 32.5%', category: 'DEF-Fuel')
    Product.create!(id: 'DEF25', name: 'DEF 2.5 GAL', category: 'DEF')

    assert_equal 'buy', Product.find('901').order_item_type
    assert_equal 'production', Product.find('DEF25').order_item_type
    PdiOrderApiImportService.call(feed)
    lines = CustomerOrder.find_by!(external_order_no: 'OD-051313-26').customer_order_products
    assert_equal %w[buy buy], lines.where(product_id: '901').pluck(:item_type)
  end

  test 'orders carried by our own trucks (1514) are dispatchable; others only when entered in the app' do
    PdiCarrier.create!(pdi_carrier_id: '1514', name: 'Five Points Logistics, LLC')
    PdiOrderApiImportService.call(feed)

    fuel = CustomerOrder.find_by!(external_order_no: 'OD-051313-26')
    assert_equal ['1514', 'Five Points Logistics, LLC'], [fuel.pdi_carrier_id, fuel.carrier]
    yard = Location.create!(company_name: 'Dispatch Yard', location_category_id: 2)
    entered = CustomerOrder.create!(location: yard, order_status: 'open_order')
    ftp = CustomerOrder.create!(location: yard, order_status: 'open_order', external_order_no: 'OD-1',
                                carrier: 'Five Points Service, Inc.')
    other = CustomerOrder.create!(location: yard, order_status: 'open_order', external_order_no: 'OD-2',
                                  pdi_carrier_id: '1590', carrier: 'Old Dominion Freight Line, Inc.')

    dispatchable = CustomerOrder.dispatchable
    assert_includes dispatchable, fuel
    assert_includes dispatchable, entered
    assert_includes dispatchable, ftp
    assert_not_includes dispatchable, other
    assert_not_includes dispatchable, CustomerOrder.find_by!(external_order_no: 'OD-050103-26'), 'no carrier'
  end
end
