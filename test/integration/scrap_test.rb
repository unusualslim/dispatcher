require 'test_helper'

class ScrapTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'scrap-admin@example.com', password: 'password123', role: 'admin')
    @product = Product.create!(id: 'SCR-1', name: 'Coolant 50/50 6/1G')
    @order = ProductionOrder.create!(number: 'PO-SCR', product: @product, status: 'in_progress', qty_to_make: 100)
  end

  test 'reasons are added and retired; scrap is recorded on an order and shows in the variance report' do
    post scrap_reasons_path, params: { scrap_reason: { name: 'Forklift damage' } }
    reason = ScrapReason.find_by!(name: 'Forklift damage')
    get scrap_reasons_path
    assert_select "input[value='Forklift damage']"

    post production_order_production_order_scraps_path(@order),
         params: { production_order_scrap: { scrap_reason_id: reason.id, quantity: 3, notes: 'Dropped pallet' } }
    assert_redirected_to production_order_path(@order)
    get production_order_path(@order)
    assert_select 'td', text: 'Forklift damage'

    patch scrap_reason_path(reason), params: { scrap_reason: { name: 'Forklift damage', active: '0' } }
    assert_not reason.reload.active
    assert_equal 1, @order.production_order_scraps.count

    @order.update_columns(status: 'completed', date_completed: Time.current, total_qty_produced: 97) # rubocop:disable Rails/SkipsModelValidations
    row = Reports::ProductionVariance.new({}).rows.first
    assert_equal 3, row[:scrapped].to_i
  end
end
