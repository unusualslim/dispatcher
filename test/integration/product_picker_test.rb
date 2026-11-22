require 'test_helper'

# Product pickers across the app show "Name (ID)" and are searchable, so a product can be found by its ID.
class ProductPickerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @product = Product.create!(id: 'PP-4417', name: 'Picker DEF')
    @site = Location.create!(company_name: 'Picker Site', city: 'Albany', location_category_id: 2)
    Tank.create!(location: @site, name: 'T-1', product: @product)
    sign_in User.create!(email: 'picker-admin@example.com', password: 'password123', role: 'admin')
  end

  test 'product pickers list products by name and ID' do
    pages = {
      new_purchase_order_path => 'select.po-product-select',
      new_location_location_product_path(@site) => 'select.js-select2',
      new_inventory_adjustment_path => 'select.js-select2',
      inventory_transactions_path => 'select.js-select2',
      tanks_path => 'select.js-select2',
      new_pricing_rule_path => 'select.select2-products',
      report_path('open_order_lines') => 'select.report-select2'
    }
    pages.each do |path, picker|
      get path
      assert_response :success, path
      assert_select "#{picker} option[value=\"PP-4417\"]", { text: /Picker DEF \(PP-4417\)/ }, path
    end
  end
end
