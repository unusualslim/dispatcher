require 'test_helper'

class GlLedgerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  fixtures :products, :locations, :location_categories

  setup do
    sign_in User.create!(email: 'admin-ledger@example.com', password: 'password123', role: 'admin')
    product = products(:def_finished)
    ReportingGroup.create!(name: 'DEF', item_type: 'warehouse')
    product.update!(pdi_repack_fee: 0.75, category: 'DEF')
    overhead = ReportingGroup.create!(name: 'Overhead', item_type: 'non_inventory', gl_account: '8005-01')
    product.product_cost_lines.create!(description: 'Supervisor', reporting_group: overhead, unit_cost: 0.0914)
    AppSetting.set('gl_account.repack_clearing', '8001-01')
    AppSetting.set('gl_account.variance', '8006-01')
    locations(:warehouse).update!(pdi_site_code: '0002')
    @po = ProductionOrder.create!(product: product, location: locations(:warehouse), total_qty_produced: 1000,
                                  status: 'completed')
  end

  test 'post now, view the frozen entry, download, reverse' do
    get production_order_path(@po)
    assert_select '#po-gl button', 'Post now'

    post ledger_entries_path(production_order_id: @po.id)
    assert_redirected_to "#{production_order_path(@po)}#gl-posting"
    follow_redirect!
    assert_select '#po-gl', /Journal Entry #{@po.number}/
    assert_select '#po-gl td.font-monospace', '0002-8001-01'

    get ledger_entries_path
    assert_response :success
    assert_select 'td.font-monospace a', @po.number

    get download_ledger_entries_path
    assert_equal 'text/csv', response.media_type
    assert_match '0002-8005-01', response.body
    assert_equal 'approved', LedgerEntry.last.status, 'download does not mark exported'

    post reverse_ledger_entry_path(LedgerEntry.last)
    assert_equal 2, LedgerEntry.count
    assert_nil LedgerEntry.active_for(@po)
  end

  test 'a posted production order cannot be deleted' do
    LedgerEntry.post!(ProductionOrderJournal.new(@po), nil)
    delete production_order_path(@po)

    assert ProductionOrder.exists?(@po.id)
  end

  test 'GL posting start date is set in costing settings' do
    patch costing_settings_path, params: { labor_rate: '25', gl_posting_start_date: '2026-11-01' }
    assert_equal Date.new(2026, 11, 1), ProductionGlPosting.start_date

    patch costing_settings_path, params: { labor_rate: '25', gl_posting_start_date: 'soon' }
    assert_response :unprocessable_content
  end
end
