require 'test_helper'

class ExpensePurchaseOrdersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    @vendor = Vendor.create!(id: 'EXPI-V', name: 'Filler Parts Inc', city: 'Macon', state: 'GA')
    @vendor.update!('address_1' => '1 Gear St')
    @plant = Location.create!(company_name: 'EXPI Plant', pdi_site_code: '0002', location_category_id: 1)
    @filler = Thing.create!(name: 'Filler 2', category: 'equipment', location: @plant)
    @account = ExpenseAccount.create!(account: '6150-01', name: 'R&M Packaging')
    sign_in User.create!(email: 'expense-po-admin@example.com', password: 'password123', role: 'admin')
  end

  test 'create, view, print and edit an expense PO' do
    get new_purchase_order_path(type: 'expense')
    assert_response :success
    assert_select 'h1', text: 'New Expense Purchase Order'
    assert_select 'input[name="purchase_order[po_type]"][value="expense"]'
    new_line = 'template#line-item-template [name^="purchase_order[line_items_attributes][NEW_INDEX]"]'
    assert_select "#{new_line}[name$='[product_name]']"
    assert_select "#{new_line}[name$='[equipment_id]'] option[data-site-id='#{@plant.id}']", text: 'Filler 2'

    post purchase_orders_path, params: { purchase_order: {
      po_type: 'expense', vendor_id: @vendor.id, location_id: @plant.id, notes: 'Rush please',
      line_items_attributes: { '0' => { product_name: 'Nozzle seal kit', vendor_part_number: 'NS-100', quantity: 3,
                                        package_code: 'EA', unit_cost: 12.5, expense_account_id: @account.id,
                                        equipment_id: @filler.id, _destroy: '0' } }
    } }
    po = PurchaseOrder.last
    assert_redirected_to purchase_order_path(po)
    assert po.expense?
    assert_equal '0002-6150-01', po.line_items.first.gl_account_code

    get purchase_order_path(po)
    assert_response :success
    assert_select 'td', text: '0002-6150-01'
    assert_select 'button', text: 'Approve'

    get print_purchase_order_path(po)
    assert_response :success
    assert_select 'h1', text: 'Purchase Order'
    assert_select 'td', text: 'NS-100'
    assert_select '.box', text: /Filler Parts Inc.*1 Gear St/m
    assert_select '.notes', text: /Rush please/

    get edit_purchase_order_path(po)
    assert_response :success
    line = po.line_items.first
    patch purchase_order_path(po), params: { purchase_order: {
      po_type: 'inventory',
      line_items_attributes: { '0' => { id: line.id, _destroy: '1' },
                               '1' => { product_name: 'O-rings', quantity: 10, unit_cost: 1, _destroy: '0' } }
    } }
    po.reload
    assert po.expense?, 'the type is fixed once created'
    assert_equal ['O-rings'], po.line_items.map(&:product_name)

    patch approve_purchase_order_path(po)
    assert_match(/needs a GL account/, flash[:alert])
  end

  test 'type filter, expense accounts page, report and equipment history' do
    po = PurchaseOrder.create!(po_type: 'expense', vendor: @vendor, location: @plant, status: 'draft',
                               line_items_attributes: [{ product_name: 'Belt', quantity: 1, unit_cost: 80,
                                                         expense_account_id: @account.id, equipment_id: @filler.id }])

    get purchase_orders_path(type: 'expense')
    assert_response :success
    assert_select 'a', text: po.display_number

    post expense_accounts_path, params: { expense_account: { account: '6160-02', name: 'Shop supplies' } }
    assert_redirected_to expense_accounts_path
    get expense_accounts_path
    assert_select 'input[value="6160-02"]'

    get report_path('expense_po_spend')
    assert_response :success
    assert_select 'td', text: 'Belt'

    get thing_path(@filler)
    assert_response :success
    assert_select 'td', text: /Belt/
  end

  test 'a failed inventory PO save re-renders the form' do
    post purchase_orders_path, params: { purchase_order: { vendor_id: '' } }
    assert_response :unprocessable_content
  end
end
