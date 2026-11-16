require 'test_helper'

class PurchaseOrderPalletLabelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    vendor = Vendor.create!(id: 'PLT-V', name: 'Pallet Supply Co')
    warehouse = Location.create!(company_name: 'Perry Brothers Oil', pdi_site_code: '2171', location_category_id: 1)
    @po = PurchaseOrder.create!(vendor: vendor, location: warehouse, pdi_reference: 'PO-4455',
                                status: 'received', received_at: Time.zone.local(2026, 11, 12, 9))
    product = Product.create!(id: 'PLT-901', name: 'DEF 2.5 gal x2')
    @po.line_items.create!(product: product, quantity: 120, package_code: 'CS', unit_cost: 10)
    sign_in User.create!(email: 'pallet-labels@example.com', password: 'password123', role: 'admin')
  end

  test 'prints one 4x6 label per pallet with company, PO, vendor, date, products and a QR link' do
    get purchase_order_path(@po)
    assert_select "a[href='#{pallet_labels_purchase_order_path(@po)}']", text: /Pallet Labels/

    get pallet_labels_purchase_order_path(@po, count: 3)
    assert_response :success
    assert_select 'section.label', 3
    assert_select '.company', text: AppSetting.company['name']
    assert_select '.po .v', text: 'PO-4455'
    assert_select '.vendor .v', text: 'Pallet Supply Co'
    assert_select '.row .v', text: '11/12/2026'
    assert_select '.row .v', text: '2171'
    assert_select '.products .name', text: 'DEF 2.5 gal x2'
    assert_select '.products td.id', text: 'PLT-901'
    assert_select ".qr[data-qr='#{purchase_order_url(@po)}']", 3
    assert_select '.pallet', text: 'Pallet 3 of 3'
  end

  test 'pallet count defaults to one and is capped' do
    get pallet_labels_purchase_order_path(@po)
    assert_select 'section.label', 1
    get pallet_labels_purchase_order_path(@po, count: 5000)
    assert_select 'section.label', PurchaseOrdersController::PALLET_LABEL_LIMIT
  end

  test 'a typed note prints on every label; none prints an empty box' do
    get pallet_labels_purchase_order_path(@po, count: 2)
    assert_select '.label .note[hidden]', 2

    get pallet_labels_purchase_order_path(@po, count: 2, note: '  Hold for   QC release  ')
    assert_select '.label .note:not([hidden]) [data-note]', text: 'Hold for QC release', count: 2
    assert_select 'input.note[value=?]', 'Hold for QC release'
  end
end
