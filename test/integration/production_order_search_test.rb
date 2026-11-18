require 'test_helper'

class ProductionOrderSearchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  fixtures :products

  setup do
    sign_in User.create!(email: 'admin-search@example.com', password: 'password123', role: 'admin')
    product = products(:def_finished)
    %w[PDI-15195 PDI-15160 PO-OTHER].each do |number|
      ProductionOrder.create!(number: number, product: product, item: product.name, status: 'created', qty_to_make: 1)
    end
  end

  test 'the index search box (sent as search) filters by order number' do
    get production_orders_path, params: { search: 'PDI-15195' }

    assert_response :success
    assert_select 'td', text: /PDI-15195/
    assert_select 'td', text: /PDI-15160/, count: 0
    assert_select 'td', text: /PO-OTHER/, count: 0
  end

  test 'the older q parameter still works' do
    get production_orders_path, params: { q: 'PDI-15160' }

    assert_select 'td', text: /PDI-15160/
    assert_select 'td', text: /PDI-15195/, count: 0
  end

  test 'the product group filter narrows the list and the kanban; MRP takes it too' do
    products(:def_finished).update!(category: 'DEF')
    coolant = Product.create!(id: 'POS-COOL', name: 'Coolant 50/50', category: 'Coolant')
    ProductionOrder.create!(number: 'PO-COOL', product: coolant, item: coolant.name, status: 'created', qty_to_make: 1)

    get production_orders_path, params: { group: 'Coolant' }
    assert_select 'td', text: /PO-COOL/
    assert_select 'td', text: /PDI-15195/, count: 0
    get kanban_production_orders_path, params: { group: 'Coolant' }
    assert_response :success
    get mrp_path, params: { group: 'Coolant' }
    assert_response :success
    assert_select 'select#group option[selected]', text: 'Coolant'
  end
end
