require 'test_helper'

class InventoryGlPostingTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories, :vendors

  setup do
    AppSetting.set(InventoryRevaluation::START_DATE_KEY, '2026-10-01')
    AppSetting.set('gl_posting_start_date', '2026-10-01')
    @location = locations(:warehouse).tap { |l| l.update!(pdi_site_code: '0002') }
    @product = products(:urea)
    @product.update!(category: 'Chemicals', standard_cost: 1.00)
    @group = ReportingGroup.find_by!(name: 'Chemicals')
    @group.update!(costing_method: 'standard', post_inventory_gl: true, inventory_gl_account: '1410-02',
                   cogs_gl_account: '5010-02', ppv_gl_account: '5090-02', receipts_clearing_gl_account: '2010-01',
                   adjustment_gl_account: '5080-02', revaluation_gl_account: '5095-02')
    LocationProduct.where(product: @product).delete_all
  end

  def move(qty, type, **details)
    InventoryPosting.post!(product: @product.reload, location: @location, quantity: qty, movement_type: type,
                           **details)
  end

  def lines(entry)
    entry.ledger_lines.map { |l| [l.account, l.debit&.to_f, l.credit&.to_f] }
  end

  test 'a receipt posts inventory at standard, PPV and the clearing account at actual' do
    po = PurchaseOrder.create!(vendor: vendors(:chem_supply), location: @location, status: 'received',
                               pdi_reference: 'FPS1102')
    move(100, 'receipt', unit_cost: 1.25, source: po, reference: 'FPS1102')

    assert_equal 1, InventoryGlPosting.post_pending!
    entry = LedgerEntry.find_by!(reference_number: 'FPS1102')
    assert_equal po, entry.source
    assert_equal [['0002-1410-02', 100.0, nil], ['0002-5090-02', 25.0, nil], ['0002-2010-01', nil, 125.0]], lines(entry)
    assert_equal 0, InventoryGlPosting.pending.count
  end

  test 'a sale posts COGS; its reversal posts again under the next reference' do
    order = CustomerOrder.create!(external_order_no: 'OD-9', order_status: 'billed', location: locations(:terminal))
    sale = move(-10, 'sale', source: order, reference: 'OD-9')
    InventoryGlPosting.post_pending!
    InventoryPosting.reverse!(sale, source: order, reference: 'OD-9')
    InventoryGlPosting.post_pending!

    assert_equal [['0002-1410-02', nil, 10.0], ['0002-5010-02', 10.0, nil]].sort,
                 lines(LedgerEntry.find_by!(reference_number: 'OD-9')).sort
    assert_equal [['0002-1410-02', 10.0, nil], ['0002-5010-02', nil, 10.0]].sort,
                 lines(LedgerEntry.find_by!(reference_number: 'OD-9-2')).sort
  end

  test 'movements wait while an account is missing, and never post for categories PDI posts' do
    @group.update!(cogs_gl_account: nil)
    move(-5, 'sale', reference: 'OD-10')

    assert_equal 0, InventoryGlPosting.post_pending!
    assert_includes InventoryGlPosting.problems, 'Chemicals has no COGS account'

    @group.update!(post_inventory_gl: false)
    assert_empty InventoryGlPosting.pending
  end

  test 'adjustments post against inventory adjustments' do
    move(4, 'adjustment', reference: 'ADJ-1')
    InventoryGlPosting.post_pending!

    assert_equal [['0002-1410-02', 4.0, nil], ['0002-5080-02', nil, 4.0]],
                 lines(LedgerEntry.find_by!(reference_number: 'ADJ-1'))
  end
end
