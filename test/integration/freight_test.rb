require 'test_helper'

# Sales → Freight Rules (rules, tables, classes), the freight card on customer orders and purchase orders, and
# Purchasing → Freight Payables.
class FreightTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @admin = User.create!(email: 'admin-freight@example.com', password: 'password123', role: 'admin')
    @terminal = Location.create!(company_name: 'Frti Terminal', location_category_id: 1)
    @site = Location.create!(company_name: 'Frti Site', location_category_id: 2)
    @carrier = Vendor.create!(id: 'FRTI-C', name: 'Frti Carrier')
    @class_a = FreightClass.create!(code: 'IA', full_load_quantity: 8000)
    @product = Product.create!(id: 'FRTI-DEF', name: 'Frti DEF', category: 'FRTI-BULK')
    @order = CustomerOrder.create!(location: @site, order_status: 'open_order', order_date: Date.current)
    @order.customer_order_products.create!(product: @product, quantity: 4000, price: 2.5)
    sign_in @admin
  end

  test 'set up a class, a pasted mileage table and a rule, then calculate an order' do
    post assign_freight_classes_path, params: { category: 'FRTI-BULK', freight_class_id: @class_a.id }
    assert_equal @class_a, @product.reload.freight_class

    post freight_tables_path, params: { freight_table: { name: 'Frti miles', lookup_type: 'mileage' } }
    table = FreightTable.find_by!(name: 'Frti miles')
    post import_freight_table_rates_path(table), params: { rows: "From\tTo\tRate\n0\t100\t0.06\n100\t\t0.09" }
    assert_equal 2, table.rates.count
    get freight_table_path(table)
    assert_response :success
    assert_select 'td', text: 'Over 100 mi'

    post freight_rules_path, params: { freight_rule: { name: 'Frti sale', side: 'sale', charge_type: 'freight',
                                                       basis: 'per_unit', freight_table_id: table.id,
                                                       freight_class_id: @class_a.id, effective_from: '2026-01-01',
                                                       active: '1' } }
    assert_redirected_to freight_rules_path
    get freight_rules_path
    assert_select 'td', text: 'Frti sale'

    patch customer_order_freight_path(@order), params: { recalculate: '1', customer_order: {
      freight_origin_location_id: @terminal.id, freight_carrier_id: @carrier.id, freight_miles: 120,
      freight_extra_stops: 0, freight_pump_offs: 0, freight_presentation: 'in_price'
    } }
    assert_redirected_to customer_order_path(@order, anchor: 'freight')
    assert_equal 360.to_d, @order.order_freight_charges.sole.amount # 4,000 × 0.09

    get customer_order_path(@order)
    assert_response :success
    assert_select '#freight', /Freight margin/
    assert_select 'td', %r{2\.5900/unit delivered}
  end

  test 'manual charges: carrier cost makes a payable, sale at cost plus markup' do
    post customer_order_freight_charges_path(@order), params: { order_freight_charge: {
      side: 'purchase', charge_type: 'freight', description: 'LTL', carrier_id: @carrier.id, amount: 200
    } }
    post customer_order_freight_charges_path(@order), params: { order_freight_charge: {
      side: 'sale', charge_type: 'freight', markup_percent: 20
    } }
    assert_equal 240.to_d, @order.order_freight_charges.sale.sole.amount
    payable = @order.freight_payables.sole
    assert_equal 200.to_d, payable.accrued_amount

    get freight_payables_path
    assert_select 'td', /Frti Carrier/
    patch freight_payable_path(payable), params: { freight_payable: { invoice_no: 'C-1', amount: 210 } }
    assert_equal 'invoiced', payable.reload.status
  end

  test 'PO freight: land by value, separate carrier invoice replaces the estimate before posting' do
    vendor = Vendor.create!(id: 'FRTI-V', name: 'Frti Vendor')
    po = PurchaseOrder.create!(vendor: vendor, location: @terminal, status: 'submitted')
    po.line_items.create!(product: @product, quantity: 10, unit_cost: 20)

    patch purchase_order_freight_path(po), params: {
      purchase_order: { freight_amount: 50, freight_allocation: 'value', freight_source: 'carrier',
                        freight_vendor_id: @carrier.id, freight_bol: 'B-9', freight_accrued: '1' }
    }
    assert_equal 'accrued', po.freight_payables.sole.status

    patch purchase_order_freight_path(po), params: {
      purchase_order: { freight_amount: 50, freight_allocation: 'value', freight_source: 'carrier',
                        freight_vendor_id: @carrier.id, freight_accrued: '1' },
      freight_invoice: { invoice_no: 'K-1', invoice_date: '2026-10-29', amount: 60 }
    }
    po.reload
    assert_equal [60.to_d, false], [po.freight_amount, po.freight_accrued]
    assert_equal ['invoiced', 0.to_d], [po.freight_payables.sole.status, po.freight_payables.sole.variance]

    get purchase_order_path(po)
    assert_response :success
    assert_select '#freight'
    assert_select 'th', text: 'Landed Unit'
  end

  test 'freight classes page, the user guide, and permissions' do
    get freight_classes_path
    assert_response :success
    assert_select 'input[value=?]', 'IA'
    get docs_freight_guide_path
    assert_select 'h1', 'Freight'

    sign_in User.create!(email: 'viewer-freight@example.com', password: 'password123', role: 'staff',
                         permissions: { 'sales' => 'view' })
    get freight_rules_path
    assert_response :success
    post freight_classes_path, params: { freight_class: { code: 'ZZ', full_load_quantity: 1 } }
    assert_nil FreightClass.find_by(code: 'ZZ')
  end
end
