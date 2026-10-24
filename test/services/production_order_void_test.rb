require 'test_helper'

class ProductionOrderVoidTest < ActiveSupport::TestCase
  fixtures :products, :product_components, :users, :locations, :location_categories

  setup do
    @admin = users(:admin_user)
    @location = locations(:warehouse)
    @product = products(:def_finished)
    @po = ProductionOrder.create!(product: @product, location: @location, qty_to_make: 100, total_qty_produced: 100)
    @po.build_components_from_bom!
    @po.save!
    LocationProduct.adjust!(@location, products(:def_concentrate), 500)
    batch = @po.production_order_batches.create!(batch_number: 'B1', quantity: 100, qc_status: 'passed')
    batch.complete_and_deduct_inventory!(@admin)
  end

  def stock(product)
    LocationProduct.find_by(location: @location, product: product)&.quantity.to_d
  end

  test 'voiding reverses the inventory completed batches moved' do
    assert_equal 100, stock(@product)
    concentrate_after_batch = stock(products(:def_concentrate))

    ProductionOrderVoid.new(@po, @admin, 'Entered twice').call!

    assert_equal 0, stock(@product)
    assert_operator stock(products(:def_concentrate)), :>, concentrate_after_batch
    assert_equal 'voided', @po.reload.status
    assert_equal ['Entered twice', @admin], [@po.void_reason, @po.voided_by]
  end

  test 'voiding reverses a posted GL entry and clocks out the crew' do
    lines = [LedgerLine.new(position: 1, account: 'A', line_description: 'x', debit: 5),
             LedgerLine.new(position: 2, account: 'B', line_description: 'y', credit: 5)]
    entry = LedgerEntry.create!(production_order: @po, reference_number: @po.number, reference_date: Time.zone.today,
                                description: 'Test', journal_id: 'FPST', approved_at: Time.current, ledger_lines: lines)
    job = @po.jobs.create!(created_by: @admin, job_type: 'Filling', started_at: 1.hour.ago)

    ProductionOrderVoid.new(@po, @admin, 'Wrong product').call!

    assert entry.reload.reversed?
    assert_not job.reload.active?
  end

  test 'voided orders are read-only, out of open work, and refuse clock-ins' do
    ProductionOrderVoid.new(@po, @admin, 'Cancelled').call!
    @po.reload

    assert_raises(ActiveRecord::ReadOnlyRecord) { @po.update!(notes: 'changed') }
    assert_not_includes ProductionOrder.where(status: ProductionOrder::OPEN_STATUSES), @po
    assert_not_includes ProductionOrder.by_status('all'), @po
    assert_includes ProductionOrder.by_status('voided'), @po
    assert_not @po.jobs.build(created_by: @admin, job_type: 'Filling', started_at: Time.current).valid?
    assert_raises(ArgumentError) { ProductionOrderVoid.new(@po, @admin, 'again').call! }
  end

  test 'a reason is required' do
    assert_raises(ArgumentError) { ProductionOrderVoid.new(@po, @admin, ' ').call! }
    assert_not @po.reload.voided?
  end
end
