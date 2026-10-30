require 'test_helper'

class PermissionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  fixtures :products

  def staff(permissions)
    User.create!(email: "staff-#{SecureRandom.hex(3)}@example.com", password: 'password123', role: 'staff',
                 permissions: permissions)
  end

  test 'levels stack and admin trumps everything' do
    user = staff('sales' => 'edit')
    assert user.can?(:sales, :view)
    assert user.can?(:sales, :edit)
    assert_not user.can?(:sales, :approve)
    assert_not user.can?(:purchasing)
    assert User.new(role: 'admin').can?(:accounting, :approve)
    assert_not User.new(role: 'worker').can?(:sales)
  end

  test 'view lets staff look but not change' do
    sign_in staff('inventory' => 'view')

    get products_path
    assert_response :success

    post products_path, params: { product: { id: 'NEW1', name: 'New' } }
    assert_redirected_to inventory_intelligence_path # no referer: falls back to their home area
    assert_not Product.exists?('NEW1')
  end

  test 'areas without access are blocked and hidden from the sidebar' do
    sign_in staff('inventory' => 'edit')

    get purchase_orders_path
    assert_redirected_to inventory_intelligence_path

    get products_path
    assert_select '#sidebar', /Inventory/
    assert_select '#sidebar', { text: /Purchasing|Accounting|Data Imports/, count: 0 }
  end

  test 'approve actions need approve' do
    po = ProductionOrder.create!(product: products(:def_finished), status: 'completed')
    sign_in staff('accounting' => 'edit', 'production' => 'view')

    get ledger_entries_path
    assert_response :success
    post ledger_entries_path(production_order_id: po.id), headers: { 'HTTP_REFERER' => ledger_entries_url }
    assert_redirected_to ledger_entries_url
    assert_equal 0, LedgerEntry.count
  end

  test 'only admins can delete' do
    product = Product.create!(id: 'DEL1', name: 'Delete me')
    sign_in staff('inventory' => 'approve')

    delete product_path(product)
    assert Product.exists?('DEL1')
  end

  test 'costing and GL tab need accounting access' do
    po = ProductionOrder.create!(product: products(:def_finished))
    sign_in staff('production' => 'edit')

    get production_order_path(po)
    assert_response :success
    assert_select '#po-gl-tab', 0
    assert_no_match 'Repack Fee Clearing', response.body
  end

  test 'form lookups work for any staff' do
    sign_in staff('production' => 'edit')

    get search_products_path, params: { q: 'DEF' }
    assert_response :success
  end

  test 'admin-only pages stay admin-only' do
    sign_in staff('sales' => 'approve', 'accounting' => 'approve')

    get users_path
    assert_redirected_to dashboard_customer_orders_path
    get imports_path
    assert_redirected_to dashboard_customer_orders_path
  end

  test 'staff with no access land on their account page' do
    sign_in staff({})

    get dispatches_path
    assert_redirected_to edit_user_registration_path
  end

  test 'admins set area access on the user page' do
    admin = User.create!(email: 'admin-perm@example.com', password: 'password123', role: 'admin')
    user = staff({})
    sign_in admin

    patch user_path(user), params: { user: { role: 'staff', permissions: { 'sales' => 'view', 'accounting' => 'approve',
                                                                           'dispatch' => '' } } }
    assert_equal({ 'sales' => 'view', 'accounting' => 'approve' }, user.reload.permissions)

    get edit_user_path(user)
    assert_select 'input[type=radio][name="user[permissions][accounting]"][value=approve][checked]'
  end

  test 'dispatch and production staff reach their screens' do
    sign_in staff('dispatch' => 'edit', 'production' => 'edit')

    get dispatches_path
    assert_response :success
    get kanban_dispatches_path
    assert_response :success
    get line_path
    assert_response :success
  end

  test 'drivers and line workers keep their screens' do
    sign_in User.create!(email: 'line-perm@example.com', password: 'password123', role: 'line_worker')
    get line_path
    assert_response :success
    get products_path
    assert_redirected_to line_path
  end
end
