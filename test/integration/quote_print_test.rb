require 'test_helper'

class QuotePrintTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(email: 'qp-admin@example.com', password: 'Password123!', role: 'admin',
                          first_name: 'Ada', last_name: 'Admin')
    customer = Customer.create!(name: 'Acme Farms')
    product = Product.create!(id: '10011219', name: 'Bulk DEF', pdi_package_code: 'GAL')
    @quote = Quote.create!(customer: customer, quote_number: 'Q-PRINT-1', status: 'draft',
                           quote_products_attributes: [{ product: product, quantity: 100, price: 2.5 }])
  end

  test 'the customer copy prints the logo, company info and lines' do
    sign_in @admin
    get print_quote_path(@quote)

    assert_response :success
    assert_includes response.body, 'fps-logo'
    assert_includes response.body, '10154 US Highway 341'
    assert_includes response.body, 'Fort Valley, GA 31030'
    assert_includes response.body, '10011219'
    assert_includes response.body, 'DRAFT'
  end

  test 'an accepted quote says its prices are held, not "once accepted"' do
    @quote.update!(status: 'accepted', locks_pricing: true, valid_from: Date.new(2026, 11, 1),
                   expiry_date: Date.new(2026, 12, 31), accepted_at: Time.zone.local(2026, 11, 5, 9))
    sign_in @admin
    get print_quote_path(@quote)

    assert_includes response.body, 'Accepted November 5, 2026'
    assert_includes response.body, 'December 31, 2026'
    assert_not_includes response.body, 'Once accepted'
    assert_not_includes response.body, 'DRAFT'
  end

  test 'admins edit the company info used on quotes' do
    sign_in @admin
    patch company_settings_path, params: { company: { name: 'Five Points Service, Inc.', address: '1 Main St',
                                                      city_state_zip: 'Fort Valley, GA 31030', phone: '555-0100' } }
    assert_redirected_to edit_company_settings_path

    get print_quote_path(@quote)
    assert_includes response.body, '1 Main St'
  end

  test 'staff without customer pricing cannot print quotes or reach company info' do
    user = staff_user('qp-staff@example.com', { 'sales' => 'view' }, flags: [])
    sign_in user
    get print_quote_path(@quote)
    assert_not_equal 200, response.status
    get edit_company_settings_path
    assert_not_equal 200, response.status
  end
end
