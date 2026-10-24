require 'test_helper'
require 'minitest/mock'

class LedgerEntryTest < ActiveSupport::TestCase
  fixtures :products, :users, :locations, :location_categories

  setup do
    @user = users(:admin_user)
    @product = products(:def_finished)
    ReportingGroup.create!(name: 'DEF', item_type: 'warehouse')
    @product.update!(pdi_repack_fee: 0.75, category: 'DEF')
    consumables = ReportingGroup.create!(name: 'Consumables', item_type: 'non_inventory', gl_account: '8002-01')
    labor = ReportingGroup.create!(name: 'Labor', item_type: 'non_inventory', labor: true, gl_account: '8003-01',
                                   temp_gl_account: '8004-01')
    @product.product_cost_lines.create!(description: 'Pallet', reporting_group: consumables, unit_cost: 13.40,
                                        per_quantity: 80)
    @product.product_cost_lines.create!(description: 'Labor', reporting_group: labor, per_quantity: 134)
    AppSetting.set('gl_account.repack_clearing', '8001-01')
    AppSetting.set('gl_account.variance', '8006-01')
    locations(:warehouse).update!(pdi_site_code: '0002')
    @po = ProductionOrder.create!(product: @product, location: locations(:warehouse), total_qty_produced: 2680,
                                  status: 'in_progress')
    clock(20)
  end

  def clock(hours)
    start = 2.days.ago
    job = @po.jobs.create!(created_by: @user, job_type: 'Filling', started_at: start, ended_at: start + hours.hours)
    job.job_workers.create!(user: @user, clocked_in_at: start, clocked_out_at: start + hours.hours)
  end

  def complete!
    @po.update!(status: 'quality_check') unless @po.status == 'quality_check'
    @po.update!(status: 'completed')
    @po.reload
  end

  test 'posting freezes the journal and later changes do not touch it' do
    complete!
    entry = LedgerEntry.post!(ProductionOrderJournal.new(@po), @user)

    assert_equal @po.number, entry.reference_number
    assert_equal Time.zone.today, entry.reference_date
    assert_equal '0002-8001-01', entry.ledger_lines.first.account
    assert_equal entry.total_debits, entry.total_credits

    AppSetting.set('labor_rate', '40')
    assert_equal 2010.00, entry.reload.ledger_lines.first.debit
    assert_raises(ArgumentError) { LedgerEntry.post!(ProductionOrderJournal.new(@po), @user) }
  end

  test 'reversal mirrors the entry and lets the order post again' do
    complete!
    entry = LedgerEntry.post!(ProductionOrderJournal.new(@po), @user)
    reversal = entry.reverse!(@user)

    assert_equal "#{@po.number}-REV", reversal.reference_number
    assert_equal entry.ledger_lines.map(&:debit), reversal.ledger_lines.map(&:credit)
    assert_nil LedgerEntry.active_for(@po)
    assert_raises(ArgumentError) { entry.reload.reverse!(@user) }
    assert_equal "#{@po.number}-2", LedgerEntry.post!(ProductionOrderJournal.new(@po), @user).reference_number
  end

  test 'completing an order posts automatically from the start date on' do
    complete!
    assert_nil LedgerEntry.active_for(@po), 'no start date: automatic posting is off'

    AppSetting.set('gl_posting_start_date', Time.zone.today.iso8601)
    @po.update!(status: 'in_progress')
    complete!
    entry = LedgerEntry.active_for(@po)
    assert entry
    assert_nil entry.approved_by
  end

  test 'orders completed before the start date are not posted automatically' do
    AppSetting.set('gl_posting_start_date', (Time.zone.today + 1).iso8601)
    complete!

    assert_nil LedgerEntry.active_for(@po)
    assert_equal 0, ProductionGlPosting.post_ready_orders!
  end

  test 'reopening a posted order reverses its entry' do
    AppSetting.set('gl_posting_start_date', Time.zone.today.iso8601)
    complete!
    entry = LedgerEntry.active_for(@po)

    @po.update!(status: 'in_progress')
    assert entry.reload.reversed?
  end

  test 'the scheduled sweep posts orders that became ready later' do
    AppSetting.set('gl_posting_start_date', Time.zone.today.iso8601)
    @product.update!(pdi_repack_fee: nil)
    complete!
    assert_nil LedgerEntry.active_for(@po)

    @product.update!(pdi_repack_fee: 0.75)
    assert_equal 1, ProductionGlPosting.post_ready_orders!
    assert_equal 0, ProductionGlPosting.post_ready_orders!
  end

  test 'export sends pending entries once and keeps them pending if the upload fails' do
    complete!
    entry = LedgerEntry.post!(ProductionOrderJournal.new(@po), @user)

    failing = PdiGlExport.new
    failing.stub(:upload, ->(*) { raise 'FTP down' }) { assert_raises(RuntimeError) { failing.run } }
    assert_equal 'approved', entry.reload.status
    assert_equal 'failed', SyncLog.for_process(PdiGlExport::PROCESS_NAME).first.status

    export = PdiGlExport.new
    sent = nil
    export.stub(:upload, ->(_name, content) { sent = content }) { assert_equal 1, export.run }
    assert entry.reload.exported?
    assert_match(/\A#{@po.number},#{Time.zone.today.strftime('%m/%d/%Y')},.*,FPST,No,0002-8001-01,,/, sent)
    assert_raises(PdiGlExport::NothingToExport) { PdiGlExport.new.run }
  end
end
