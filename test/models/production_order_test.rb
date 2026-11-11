require 'test_helper'

class ProductionOrderTest < ActiveSupport::TestCase
  fixtures :users

  test 'new orders start as created' do
    assert_equal 'created', ProductionOrder.create!.status
  end

  test 'the first clock-in moves a created order to in progress' do
    po = ProductionOrder.create!
    po.jobs.create!(created_by: users(:admin_user), job_type: 'Filling', started_at: Time.current)

    assert_equal 'in_progress', po.reload.status
  end

  test 'clocking in does not reopen a completed order' do
    po = ProductionOrder.create!(status: 'completed')
    po.jobs.create!(created_by: users(:admin_user), job_type: 'Cleanup', started_at: Time.current)

    assert_equal 'completed', po.reload.status
  end

  test 'completing stamps the completion date' do
    po = ProductionOrder.create!(status: 'quality_check', total_qty_produced: 10)
    po.update!(status: 'completed')

    assert_equal Time.zone.today, po.date_completed
  end
end

class ProductionOrderStatusRulesTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(id: 'POS-DEF', name: 'Bulk DEF 2.5')
  end

  test 'orders get a readable 6-character number' do
    number = ProductionOrder.create!.number

    assert_match(/\A[A-HJ-NP-Z2-9]{6}\z/, number)
  end

  test 'quality check assigns a lot number per product and day' do
    first = ProductionOrder.create!(product: @product, status: 'in_progress')
    second = ProductionOrder.create!(product: @product, status: 'in_progress')
    first.update!(status: 'quality_check')
    second.update!(status: 'quality_check')
    day = Time.zone.today.strftime('%Y%m%d')

    assert_equal "FPS-BULKDE-#{day}-001", first.lot_number
    assert_equal "FPS-BULKDE-#{day}-002", second.lot_number
  end

  test 'completing has to come from quality check' do
    order = ProductionOrder.create!(product: @product, status: 'in_progress', total_qty_produced: 10)

    assert_not order.update(status: 'completed')
    assert_includes order.errors[:status], 'moves to Completed from Quality Check'
  end

  test 'completing needs every quality check recorded' do
    @product.quality_specs.create!(name: 'pH', target_min: 9.5, target_max: 10.5, position: 1)
    order = ProductionOrder.create!(product: @product, status: 'quality_check', total_qty_produced: 10)

    assert_not order.update(status: 'completed')
    assert_match(/pH/, order.errors[:base].join)
  end

  test 'voided is only set by voiding' do
    order = ProductionOrder.create!(product: @product)

    assert_not order.update(status: 'voided')
    assert order.errors.key?(:status)
  end

  test 'the default list hides voided orders' do
    open = ProductionOrder.create!(product: @product)
    voided = ProductionOrder.create!(product: @product)
    voided.update_columns(status: 'voided', voided_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_includes ProductionOrder.by_status('').ids, open.id
    assert_not_includes ProductionOrder.by_status('').ids, voided.id
    assert_includes ProductionOrder.by_status('voided').ids, voided.id
  end
end
