require 'test_helper'

class PurchaseOrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    @vendor = Vendor.create!(id: 'POT-V', name: 'POT Vendor', lead_time_days: 5)
    @warehouse = Location.create!(company_name: 'POT Warehouse', location_category_id: 1)
    @product = Product.create!(id: 'POT-P', name: 'POT Product')
    @user = User.create!(email: 'pot@example.com', password: 'password123', role: 'admin')
  end

  def po(**attrs)
    PurchaseOrder.create!(vendor: @vendor, location: @warehouse, status: 'draft', **attrs)
  end

  test 'status must be a known one' do
    order = PurchaseOrder.new(vendor: @vendor, status: 'shipped')

    assert_not order.valid?
    assert order.errors.key?(:status)
  end

  test 'approving records who and the expected date from the vendor lead time' do
    order = po
    order.approve!(@user)

    assert_equal 'approved', order.status
    assert_equal @user, order.approved_by
    assert_equal Date.today + 5, order.expected_delivery_date # rubocop:disable Rails/Date -- matches approve!
  end

  test 'submitting an app PO sends it to PDI' do
    order = po(status: 'approved')

    assert_enqueued_with(job: PdiExportJob, args: [order.id]) { order.update!(status: 'submitted') }
  end

  test 'PDI-imported POs and other updates are not sent to PDI' do
    from_pdi = po(status: 'approved', trigger_type: 'pdi_import')
    order = po(status: 'submitted')

    assert_no_enqueued_jobs(only: PdiExportJob) do
      from_pdi.update!(status: 'submitted')
      order.update!(notes: 'called vendor')
    end
  end

  test 'receiving then posting adds stock once' do
    order = po(status: 'approved')
    order.line_items.create!(product: @product, quantity: 40, unit_cost: 2.5)
    order.mark_received!(@user)

    assert order.postable?
    assert order.post_to_inventory!(@user)
    assert_not order.post_to_inventory!(@user), 'a second post is a no-op'
    assert_not order.reload.postable?
    assert_in_delta 40, LocationProduct.find_by(location: @warehouse, product: @product).quantity
  end

  test 'dropship POs (no warehouse) never post to inventory' do
    order = po(location: nil, status: 'received')

    assert_not order.postable?
    assert_raises(ArgumentError) { order.post_to_inventory!(@user) }
  end

  test 'display number prefers the PDI reference' do
    assert_equal 'PDI-77', po(pdi_reference: 'PDI-77').display_number
    order = po
    assert_equal "##{order.id}", order.display_number
  end
end
