require 'test_helper'

class ProductionOrderCostingTest < ActiveSupport::TestCase
  fixtures :products, :users

  setup do
    @product = products(:def_finished)
    @product.update!(pdi_repack_fee: 0.75)
    # From the 1/2.5 squat cost sheet
    @consumables = ReportingGroup.create!(name: 'Consumables', item_type: 'non_inventory', gl_account: '6990-01')
    @labor = ReportingGroup.create!(name: 'Labor', item_type: 'non_inventory', labor: true, gl_account: '6100-12',
                                    temp_gl_account: '6935-02')
    @overhead = ReportingGroup.create!(name: 'Overhead', item_type: 'non_inventory', gl_account: '5100-25')
    lines = @product.product_cost_lines
    lines.create!(description: 'Pallet', reporting_group: @consumables, unit_cost: 13.40, per_quantity: 80)
    lines.create!(description: 'Supervisor', reporting_group: @overhead, unit_cost: 0.0914)
    lines.create!(description: 'Variable labor', reporting_group: @labor, per_quantity: 134)

    @po = ProductionOrder.create!(product: @product, total_qty_produced: 2680)
    @user = users(:admin_user)
  end

  def clock(hours, user: @user)
    start = 1.day.ago
    job = @po.jobs.create!(created_by: @user, job_type: 'Filling', started_at: start, ended_at: start + hours.hours)
    job.job_workers.create!(user: user, clocked_in_at: start, clocked_out_at: start + hours.hours)
  end

  test 'labor efficiency compares earned standard hours to /line hours' do
    clock(16)
    clock(9) # 25 actual hours; 2,680 ÷ 134 = 20 standard hours
    costing = ProductionOrderCosting.new(@po)

    assert_in_delta 20, costing.standard_labor_hours, 0.0001
    assert_in_delta 25, costing.actual_labor_hours, 0.0001
    assert_in_delta 0.8, costing.labor_efficiency, 0.0001
    assert_in_delta 500, costing.standard_labor_cost, 0.01
    assert_in_delta 625, costing.actual_labor_cost, 0.01
  end

  test 'variance is the repack fee less supplies and overhead at standard and labor at actual' do
    clock(25)
    costing = ProductionOrderCosting.new(@po)

    absorbed = (2680 * 0.1675) + (2680 * 0.0914) + 625
    assert_in_delta absorbed, costing.absorbed_cost, 0.01
    assert_in_delta 2010, costing.repack_fee_applied, 0.01
    assert_in_delta 2010 - absorbed, costing.variance, 0.01
  end

  test 'actual hours split by employment type' do
    temp = User.create!(email: 'temp-worker@example.com', password: 'password123', role: 'line_worker',
                        employment_type: 'temp')
    clock(16)
    clock(9, user: temp)

    by_type = ProductionOrderCosting.new(@po).actual_labor_hours_by_type
    assert_in_delta 16, by_type['full_time'], 0.0001
    assert_in_delta 9, by_type['temp'], 0.0001
  end

  test 'no variance without a repack fee and no efficiency without hours' do
    @product.update!(pdi_repack_fee: nil)
    costing = ProductionOrderCosting.new(@po)

    assert_nil costing.variance
    assert_nil costing.labor_efficiency
  end

  test 'quantity falls back to batch totals' do
    @po.update!(total_qty_produced: nil)
    @po.production_order_batches.create!(batch_number: 'B1', quantity: 100)
    @po.production_order_batches.create!(batch_number: 'B2', quantity: 34)

    assert_equal 134, ProductionOrderCosting.new(@po.reload).qty_produced
  end
end
