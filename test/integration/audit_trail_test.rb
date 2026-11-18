require 'test_helper'

class AuditTrailTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'changes are recorded with the user and shown in the History panel, cost fields only to cost viewers' do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    admin = User.create!(email: 'audit-admin@example.com', password: 'password123', role: 'admin')
    sign_in admin
    product = Product.create!(id: 'AUD-1', name: 'Coolant')
    patch product_path(product), params: { product: { name: 'Coolant 50/50', cost_per_unit: '4.25' } }

    version = PaperTrail::Version.where(item_type: 'Product', item_id: 'AUD-1').last
    assert_equal admin.id.to_s, version.whodunnit
    get product_path(product)
    assert_select 'details summary', text: /History/
    assert_select 'td', text: %r{Name: Coolant → Coolant 50/50}
    assert_select 'td', text: /Cost per unit/

    sign_out admin
    sign_in staff_user('audit-staff@example.com', { 'inventory' => 'view' }, flags: [])
    get product_path(product)
    assert_select 'td', text: %r{Name: Coolant → Coolant 50/50}
    assert_select 'td', text: /Cost per unit/, count: 0
  end

  test 'old history is pruned after 5 years' do
    PaperTrail::Version.create!(item_type: 'Product', item_id: 'X', event: 'update', created_at: 6.years.ago)
    PaperTrail::Version.create!(item_type: 'Product', item_id: 'X', event: 'update', created_at: 4.years.ago)
    AuditTrailPruneJob.perform_now
    assert_equal 1, PaperTrail::Version.where(item_id: 'X').count
  end
end
