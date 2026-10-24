require 'test_helper'

class ProductionOrderVoidAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :products

  test 'only admins can void production orders' do
    po = ProductionOrder.create!(product: products(:def_finished))
    sign_in User.create!(email: 'staff-void@example.com', password: 'password123', role: 'staff',
                         permissions: { 'production' => 'approve' })
    post void_production_order_path(po), params: { void_reason: 'nope' }
    assert_not po.reload.voided?

    sign_in User.create!(email: 'admin-void@example.com', password: 'password123', role: 'admin')
    post void_production_order_path(po), params: { void_reason: 'Duplicate' }
    assert po.reload.voided?
    get production_order_path(po)
    assert_select '.alert-dark', /Voided.*Duplicate/m
    get edit_production_order_path(po)
    assert_redirected_to production_order_path(po)
  end
end
