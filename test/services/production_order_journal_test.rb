require 'test_helper'

class ProductionOrderJournalTest < ActiveSupport::TestCase
  fixtures :products, :users, :locations, :location_categories

  setup do
    @user = users(:admin_user)
    @product = products(:def_finished)
    @product.update!(pdi_repack_fee: 0.75)
    @consumables = ReportingGroup.create!(name: 'Consumables', item_type: 'non_inventory', gl_account: '6990-01')
    @labor = ReportingGroup.create!(name: 'Labor', item_type: 'non_inventory', labor: true, gl_account: '6100-12',
                                    temp_gl_account: '6935-02')
    @overhead = ReportingGroup.create!(name: 'Overhead', item_type: 'non_inventory', gl_account: '5100-25')
    lines = @product.product_cost_lines
    lines.create!(description: 'Pallet', reporting_group: @consumables, unit_cost: 13.40, per_quantity: 80)
    lines.create!(description: 'Supervisor', reporting_group: @overhead, unit_cost: 0.0914)
    lines.create!(description: 'Variable labor', reporting_group: @labor, per_quantity: 134)

    location = locations(:warehouse)
    location.update!(pdi_site_code: '1234')
    @po = ProductionOrder.create!(product: @product, location: location, total_qty_produced: 2680,
                                  date_completed: Date.new(2026, 10, 24))

    AppSetting.set('gl_account.repack_clearing', '6110-01')
    AppSetting.set('gl_account.variance', '5100-99')
  end

  def clock(hours, user: @user)
    start = 2.days.ago
    job = @po.jobs.create!(created_by: @user, job_type: 'Filling', started_at: start, ended_at: start + hours.hours)
    job.job_workers.create!(user: user, clocked_in_at: start, clocked_out_at: start + hours.hours)
  end

  test 'clears the repack fee against absorbed costs and balances with variance' do
    clock(16)
    clock(9, user: User.create!(email: 'temp@example.com', password: 'password123', employment_type: 'temp'))
    journal = ProductionOrderJournal.new(@po)

    assert journal.ready?, journal.problems.inspect
    assert_equal ['Repack fee clearing', 'Consumables', 'Overhead', 'Labor (Full-time)', 'Labor (Temp)',
                  'Production variance'], journal.lines.map(&:posting)
    assert_equal %w[6110-01 6990-01 5100-25 6100-12 6935-02 5100-99], journal.lines.map(&:account)
    assert_equal 2010.00, journal.lines.first.debit
    assert_equal 400.00, journal.lines.find { |l| l.posting == 'Labor (Full-time)' }.credit
    assert_equal 225.00, journal.lines.find { |l| l.posting == 'Labor (Temp)' }.credit
    assert_equal journal.total_debits, journal.total_credits

    # 2010 − (448.90 pallet + 244.95 supervisor + 625 labor) = 691.15 favorable
    assert_equal 691.15, journal.lines.last.credit
  end

  test 'unfavorable variance is a debit' do
    clock(100)
    variance = ProductionOrderJournal.new(@po).lines.last

    assert_equal 'Production variance', variance.posting
    assert variance.debit.positive?
    assert_nil variance.credit
  end

  test 'PDI rows follow the GL import layout' do
    clock(20)
    row = PdiGlImport.rows(ProductionOrderJournal.new(@po)).first

    assert_equal [@po.number, '10/24/2026', "Prod #{@po.number} DEF Finished Product", '10', 2026, 'FPST', 'No',
                  '1234-6110-01', nil, 'Clear PDI repack fee', '2010.00', nil, nil], row
    assert_equal PdiGlImport::HEADERS.size, row.size
  end

  test 'lists what blocks the export' do
    AppSetting.set('gl_account.variance', '')
    @overhead.update!(gl_account: nil)
    @po.update!(date_completed: nil)
    @po.location.update!(pdi_site_code: nil)
    clock(20)
    problems = ProductionOrderJournal.new(@po).problems

    assert_includes problems, 'Not completed (no completion date)'
    assert_includes problems, 'Production location has no PDI site number'
    assert_includes problems, 'No GL account set for: Overhead, Production variance'
  end

  test 'no lines without a repack fee' do
    @product.update!(pdi_repack_fee: nil)
    journal = ProductionOrderJournal.new(@po)

    assert_empty journal.lines
    assert_includes journal.problems, 'Product has no PDI repack fee'
  end
end
