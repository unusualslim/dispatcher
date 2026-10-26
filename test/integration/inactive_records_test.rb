require 'test_helper'

# Inactive customers and products leave pickers and default lists but stay on records that use them.
class InactiveRecordsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "admin-#{SecureRandom.hex(3)}@example.com", password: 'password123', role: 'admin')
    @active = Customer.create!(name: 'Zz Active Farms', preferred_contact_method: 'no preference')
    @inactive = Customer.create!(name: 'Zz Gone Farms', preferred_contact_method: 'no preference', active: false)
    @product = Product.create!(id: 'ZZ-ON', name: 'Zz Live DEF', is_raw_material: false)
    @retired = Product.create!(id: 'ZZ-OFF', name: 'Zz Retired DEF', is_raw_material: false, active: false)
  end

  test 'customer list hides inactive customers unless asked, and pickers leave them out' do
    get customers_path(search: 'Zz')
    assert_includes response.body, 'Zz Active Farms'
    assert_not_includes response.body, 'Zz Gone Farms'

    get customers_path(search: 'Zz', inactive: '1')
    assert_includes response.body, 'Zz Gone Farms'

    get select2_customers_path(q: 'zz')
    assert_equal ['Zz Active Farms'], response.parsed_body.pluck('text')
  end

  test 'product list and search leave out inactive products' do
    get products_path(query: 'Zz', type: 'all')
    assert_includes response.body, 'Zz Live DEF'
    assert_not_includes response.body, 'Zz Retired DEF'

    get products_path(query: 'Zz', type: 'all', inactive: '1')
    assert_includes response.body, 'Zz Retired DEF'

    get search_products_path(q: 'Zz')
    assert_includes response.body, 'ZZ-ON'
    assert_not_includes response.body, 'ZZ-OFF'
  end

  test 'selectable keeps the record already chosen' do
    assert_equal %w[ZZ-OFF ZZ-ON], Product.selectable('ZZ-OFF').where(id: %w[ZZ-ON ZZ-OFF]).order(:id).pluck(:id)
    assert_equal [@active], Customer.selectable(nil).where(id: [@active.id, @inactive.id]).to_a
    assert_equal 2, Customer.selectable(@inactive.id).where(id: [@active.id, @inactive.id]).count
  end
end
