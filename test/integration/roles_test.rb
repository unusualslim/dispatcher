require 'test_helper'

class RolesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def role(name, levels, features: [], flags: [])
    Role.create!(name: name, area_levels: levels, features: features, data_flags: flags)
  end

  def user_with(*roles, hidden: [])
    User.create!(email: "roles-#{SecureRandom.hex(3)}@example.com", password: 'password123', role: 'staff',
                 hidden_flags: hidden).tap { |user| user.roles = roles }
  end

  test 'access adds up across roles' do
    user = user_with(role('Sales read only', { 'sales' => 'view' }, flags: %w[customer_pricing]),
                     role('Sales no costing', { 'sales' => 'edit', 'dispatch' => 'view' }, features: %w[quotes]),
                     role('AP clerk', { 'purchasing' => 'edit' }, features: %w[expense_pos]))

    assert user.can?(:sales, :edit)
    assert_not user.can?(:sales, :approve)
    assert user.can?(:dispatch)
    assert user.can_feature?(:quotes)
    assert user.can_feature?(:expense_pos)
    assert_not user.can_feature?(:inventory_pos)
    assert user.sees?(:customer_pricing)
    assert_not user.sees?(:costs)
  end

  test 'hidden data wins over roles and over admin' do
    admin = User.create!(email: 'tech@example.com', password: 'password123', role: 'admin',
                         hidden_flags: %w[financial_dashboard gl])
    assert admin.can?(:accounting, :approve)
    assert_not admin.sees?(:financial_dashboard)
    assert_not admin.sees?(:gl)
    assert admin.sees?(:costs)

    sign_in admin
    get financial_dashboard_path
    assert_redirected_to dispatches_path
    get ledger_entries_path
    assert_redirected_to dispatches_path
    get reports_path
    assert_select 'a', text: /Financial dashboard/, count: 0
    assert_select 'a', text: /Sales by customer/, count: 0
  end

  test 'a data flag gates its pages' do
    sign_in user_with(role('Inventory no costs', { 'inventory' => 'edit', 'accounting' => 'view' }))
    get inventory_transactions_path
    assert_response :success
    get inventory_valuation_path
    assert_response :redirect
    get cost_items_path
    assert_response :redirect
  end

  test 'a feature right is needed to change things, not to look' do
    vendor = Vendor.create!(id: 'ROLE-V', name: 'Role Vendor')
    sign_in user_with(role('Expense buyer', { 'purchasing' => 'edit' }, features: %w[expense_pos]))

    get purchase_orders_path
    assert_response :success
    get new_purchase_order_path(type: 'inventory')
    assert_response :redirect
    get new_purchase_order_path(type: 'expense')
    assert_response :success
    assert_no_difference('PurchaseOrder.count') do
      post purchase_orders_path, params: { purchase_order: { po_type: 'inventory', vendor_id: vendor.id } }
    end
    get edit_vendor_path(vendor)
    assert_response :redirect
  end

  test 'admins build roles' do
    sign_in User.create!(email: 'admin-roles@example.com', password: 'password123', role: 'admin')
    get new_role_path
    assert_response :success

    post roles_path, params: { role: { name: 'Sales – no costing', description: 'Order desk', assistant_level: 'off',
                                       area_levels: { 'sales' => 'edit', 'dispatch' => '' },
                                       features: ['', 'quotes'], data_flags: ['', 'customer_pricing'] } }
    role = Role.find_by!(name: 'Sales – no costing')
    assert_equal({ 'sales' => 'edit' }, role.area_levels)
    assert_equal %w[quotes], role.features
    assert_equal %w[customer_pricing], role.data_flags

    get roles_path
    assert_select 'td', text: /Sales edit/
    delete role_path(role)
    assert_not Role.exists?(role.id)
  end

  test 'staff cannot reach roles' do
    sign_in user_with(role('Everything', User::AREAS.keys.index_with('approve')))
    get roles_path
    assert_response :redirect
  end
end
