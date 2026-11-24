require 'test_helper'

# Accounting → Standard Cost Exceptions: variances and stale or missing standards, cleared by a review.
class StandardCostExceptionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    ReportingGroup.find_or_create_by!(name: 'SCE Std') do |g|
      g.item_type = 'warehouse'
    end.update!(costing_method: 'standard')
    @bought = Product.create!(id: 'SCE-B', name: 'Jug', category: 'SCE Std', standard_cost: 2)
    @blank = Product.create!(id: 'SCE-N', name: 'Cap', category: 'SCE Std')
    @fine = Product.create!(id: 'SCE-F', name: 'Label', category: 'SCE Std', standard_cost: 1)
    # 100 received at $2.30 against a $2.00 standard: +$30 (15%).
    InventoryTransaction.create!(product: @bought, quantity: 100, direction: 'in', movement_type: 'receipt',
                                 occurred_on: Date.current - 3, unit_cost: 2, total_cost: 200, variance_amount: 30,
                                 reference_number: 'PO 777')
    InventoryTransaction.create!(product: @fine, quantity: 100, direction: 'in', movement_type: 'receipt',
                                 occurred_on: Date.current - 3, unit_cost: 1, total_cost: 100, variance_amount: 1)
  end

  test 'lists receipt variances, out-of-date and missing standards, and leaves small ones off' do
    items = StandardCostExceptions.new.items
    kinds = items.map { |i| [i.kind, i.subject_key] }

    assert_includes kinds, ['missing_standard', 'product:SCE-N']
    assert_includes kinds, ['cost_drift', 'product:SCE-B'] # last receipt $2.30 vs $2.00
    ppv = items.find { |i| i.kind == 'receipt_ppv' }
    assert_equal [30, 0.15], [ppv.amount.to_i, ppv.pct.to_f]
    assert_match 'PO 777: 100 at $2.3000 vs standard $2.0000', ppv.detail
    assert(items.none? { |i| i.subject_key == 'product:SCE-F' })
  end

  test 'a review clears an exception; a drift review comes back when the numbers change' do
    admin = User.create!(email: 'sce-admin@example.com', password: 'password123', role: 'admin')
    sign_in admin
    get standard_cost_exceptions_path
    assert_response :success
    assert_select 'td', text: 'Receipt price variance'

    drift = StandardCostExceptions.new.items.find { |i| i.kind == 'cost_drift' }
    patch review_standard_cost_exceptions_path,
          params: { kind_key: 'cost_drift', subject_key: drift.subject_key, fingerprint: drift.fingerprint,
                    resolution: 'New price list coming' }
    assert_redirected_to standard_cost_exceptions_path
    assert(StandardCostExceptions.new.items.find { |i| i.kind == 'cost_drift' }.reviewed?)

    @bought.update!(standard_cost: 1.5)
    assert_not(StandardCostExceptions.new.items.find { |i| i.kind == 'cost_drift' }.reviewed?)

    patch review_standard_cost_exceptions_path, params: { kind_key: 'missing_standard', subject_key: 'product:SCE-N',
                                                          fingerprint: '', resolution: '' }
    assert_equal 'Say what was done about it.', flash[:alert]
  end

  test 'needs the costs flag to see it and accounting approval to review' do
    sign_in staff_user('sce-noflag@example.com', { 'accounting' => 'approve' }, flags: [])
    get standard_cost_exceptions_path
    assert_response :redirect

    sign_in staff_user('sce-view@example.com', { 'accounting' => 'view' })
    get standard_cost_exceptions_path
    assert_response :success
    assert_select 'input[name=resolution]', count: 0
    patch review_standard_cost_exceptions_path, params: { kind_key: 'missing_standard', subject_key: 'product:SCE-N',
                                                          fingerprint: '', resolution: 'x' }
    assert_equal 0, ExceptionReview.count
  end
end
