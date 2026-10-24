require 'test_helper'

class ProductionCostingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :products, :product_components

  setup do
    sign_in User.create!(email: 'admin-costing@example.com', password: 'password123', role: 'admin')
    @product = products(:def_finished)
    @consumables = ReportingGroup.create!(name: 'Consumables', item_type: 'non_inventory')
  end

  test 'cost lines and repack fee save from the product page and show in the rollup' do
    patch product_path(@product), params: { product: {
      pdi_repack_fee: '0.75',
      product_cost_lines_attributes: {
        '0' => { description: 'Pallet', reporting_group_id: @consumables.id, quantity: '1', unit_cost: '13.40',
                 per_quantity: '80' },
        '1' => { description: '', reporting_group_id: @consumables.id, quantity: '1', unit_cost: '', per_quantity: '1' }
      }
    } }
    assert_redirected_to product_path(@product)
    assert_equal 1, @product.product_cost_lines.count
    assert_equal 0.75, @product.reload.pdi_repack_fee

    get product_path(@product)
    assert_response :success
    assert_select 'td', text: 'Non-Inventory Costs'
    assert_match '$0.1675', response.body
  end

  test 'BOM component picker searches instead of listing every product' do
    get product_path(@product)
    assert_response :success
    # Two BOM rows, each holding only a blank and its selected component
    assert_select 'select.bom-product-select option[selected]', 2
    assert_select 'select.bom-product-select option', 4
    assert_no_match 'window.bomProducts', response.body

    get search_products_path, params: { q: 'urea' }
    assert_equal [products(:urea).id], response.parsed_body.pluck('id')
  end

  test 'production order shows the costing panel' do
    labor = ReportingGroup.create!(name: 'Labor', item_type: 'non_inventory', labor: true)
    @product.product_cost_lines.create!(description: 'Variable labor', reporting_group: labor, per_quantity: 134)
    po = ProductionOrder.create!(product: @product, total_qty_produced: 268)

    get production_order_path(po)
    assert_response :success
    assert_select '.card-header', /Costing/
    assert_match 'Standard hours earned', response.body
    assert_select '#po-gl', /Journal Entry/
    assert_match(/Standard:\s*134\s*units per worker-hour/, response.body)

    po.update!(total_qty_produced: nil)
    get production_order_path(po)
    assert_match 'No quantity produced yet', response.body
  end

  test 'labor rate is editable and validated' do
    patch costing_settings_path, params: { labor_rate: '27.5' }
    assert_redirected_to edit_costing_settings_path
    assert_equal 27.5, AppSetting.labor_rate

    patch costing_settings_path, params: { labor_rate: 'abc' }
    assert_response :unprocessable_entity
    assert_equal 27.5, AppSetting.labor_rate
  end

  test 'reporting groups are added, edited, and kept while in use' do
    post reporting_groups_path, params: { reporting_group: { name: 'Freight', gl_account: '5100-29' } }
    assert_redirected_to reporting_groups_path
    freight = ReportingGroup.find_by!(name: 'Freight')

    patch reporting_group_path(freight), params: { reporting_group: { gl_account: 'bad account' } }
    assert_equal '5100-29', freight.reload.gl_account

    def_group = ReportingGroup.create!(name: 'DEF', item_type: 'warehouse')
    patch reporting_group_path(def_group), params: { reporting_group: { post_inventory_gl: '1' } }
    assert def_group.reload.post_inventory_gl?

    @product.product_cost_lines.create!(description: 'Pallet', reporting_group: @consumables, unit_cost: 13.40)
    delete reporting_group_path(@consumables)
    assert ReportingGroup.exists?(@consumables.id)

    get reporting_groups_path
    assert_response :success
    assert_select 'input[value=?]', '5100-29'
  end

  test 'GL accounts must be Major-Sub' do
    patch costing_settings_path, params: { labor_rate: '25', gl_accounts: { repack_clearing: '6110-01' } }
    assert_equal '6110-01', ProductionOrderJournal.account_for('repack_clearing')

    patch costing_settings_path, params: { labor_rate: '25', gl_accounts: { repack_clearing: '1234-6110-01' } }
    assert_response :unprocessable_entity
    assert_match 'GL accounts must be Major-Sub, e.g. 1410-02: Repack fee clearing', response.body
    assert_equal '6110-01', ProductionOrderJournal.account_for('repack_clearing')
  end
end
