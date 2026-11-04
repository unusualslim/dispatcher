require 'test_helper'

class InventoryOpeningTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  fixtures :products, :locations, :location_categories

  setup do
    sign_in User.create!(email: 'admin-opening@example.com', password: 'password123', role: 'admin')
    @product = products(:def_finished)
    @product.update!(cost_per_unit: 4)
    LocationProduct.where(product: @product).delete_all
    LocationProduct.create!(location: locations(:warehouse), product: @product, quantity: 10)
  end

  test 'opening on a chosen day, replay, then reset back to the start' do
    get inventory_valuation_path
    assert_select 'input[name=as_of][type=date]'
    assert_select 'button', 'Reset inventory'

    post opening_inventory_valuation_path, params: { as_of: '2026-10-01' }
    assert_equal Date.new(2026, 10, 1), InventoryRevaluation.start_date
    follow_redirect!
    assert_select 'button', 'Replay'

    post replay_inventory_valuation_path, params: { from: '2026-10-01', to: '2026-10-31' }
    assert_match(/Replayed 2026-10-01…2026-10-31/, flash[:notice])

    post reset_tracking_inventory_valuation_path
    assert_nil InventoryRevaluation.start_date
    assert_equal 0, LocationProduct.find_by!(product: @product).quantity
  end

  test 'a future opening date starts today' do
    post opening_inventory_valuation_path, params: { as_of: (Date.current + 5).iso8601 }
    assert_equal Date.current, InventoryRevaluation.start_date
  end
end
