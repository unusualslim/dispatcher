require 'test_helper'

# Show pages put their actions in one header at the top, with Previous / Next through the list.
class ShowPageHeaderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(email: 'header-admin@example.com', password: 'password123', role: 'admin')
    sign_in @admin
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  def nav_hrefs
    css_select('[aria-label="Previous and next"] a').to_h { |a| [a.text.strip, a['href']] }
  end

  test 'locations step through alphabetically, with actions in the header' do
    a, b, c = ['0000 Alpha', '0000 Bravo', '0000 Charlie'].map do |n|
      Location.create!(company_name: n, location_category_id: 2)
    end

    get location_path(b)
    assert_equal({ 'Previous' => location_path(a), 'Next' => location_path(c) }, nav_hrefs)
    assert_select '.d-flex.justify-content-between a', text: 'Edit'
    assert_select '.d-flex.justify-content-between button', text: 'Delete'

    get location_path(a)
    assert_equal({ 'Next' => location_path(b) }, nav_hrefs)
    assert_select '[aria-label="Previous and next"] .disabled', text: /Previous/
  end

  test 'customers follow the remembered list filters, else go alphabetically' do
    akins, other, zane = ['0000 Akins Qzx', '0000 Middle', '0000 Zane Qzx'].map { |n| Customer.create!(name: n) }
    @admin.update!(list_filters: { 'customers' => { 'search' => 'Qzx' } })

    get customer_path(akins)
    assert_equal({ 'Next' => customer_path(zane) }, nav_hrefs)

    get customer_path(other) # filtered out of the remembered list: alphabetical instead
    assert_equal customer_path(akins), nav_hrefs['Previous']
  end

  test 'products, purchase orders and work orders have the header too' do
    first = Product.create!(id: 'HDR1', name: '0000 Aaa Product')
    second = Product.create!(id: 'HDR2', name: '0000 Bbb Product')
    get product_path(second)
    assert_equal product_path(first), nav_hrefs['Previous']
    assert_select '.d-flex.justify-content-between a', text: 'Edit'

    vendor = Vendor.create!(id: 'V-HDR', name: 'Header Vendor')
    older = PurchaseOrder.create!(vendor: vendor, status: 'draft', created_at: 1.year.from_now)
    newer = PurchaseOrder.create!(vendor: vendor, status: 'draft', created_at: 1.year.from_now + 1.hour)
    get purchase_order_path(older)
    assert_equal purchase_order_path(newer), nav_hrefs['Previous'] # the list is newest first
    assert_select '.d-flex.justify-content-between button', text: 'Approve'

    shop = Location.create!(company_name: 'Shop', location_category_id: 2)
    order = WorkOrder.create!(subject: 'Fix pump', status: 'Open', workable: shop)
    get work_order_path(order)
    assert_response :success
    assert_select '.d-flex.justify-content-between button', text: 'Mark as Critical'
  end
end
