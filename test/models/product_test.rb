require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  test 'products in a Buy reporting group are bought, not produced' do
    product = Product.create!(id: 'HYD-1', name: 'Hydraulic hose', category: 'HYDRAULICS')
    assert_equal 'production', product.order_item_type

    ReportingGroup.find_by!(name: 'HYDRAULICS').update!(buy: true)
    assert_equal 'buy', product.reload.order_item_type
  end
end
