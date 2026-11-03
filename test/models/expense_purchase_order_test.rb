require 'test_helper'

# Expense POs: parts and supplies charged to GL expense accounts, never sent to PDI or posted to inventory.
class ExpensePurchaseOrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    @vendor = Vendor.create!(id: 'EXP-V', name: 'Packaging Parts Co')
    @plant = Location.create!(company_name: 'EXP Plant', pdi_site_code: '0002', location_category_id: 1)
    @shop = Location.create!(company_name: 'EXP Shop', pdi_site_code: '0005', location_category_id: 1)
    @capper = Thing.create!(name: 'Capper line 1', category: 'equipment', location: @shop)
    @account = ExpenseAccount.create!(account: '6150-01', name: 'Repairs & Maintenance – Packaging')
  end

  def expense_po(**lines_attrs)
    PurchaseOrder.create!(po_type: 'expense', vendor: @vendor, location: @plant, status: 'draft',
                          line_items_attributes: [{ product_name: 'Chuck insert', vendor_part_number: 'CI-38',
                                                    quantity: 2, unit_cost: 45, expense_account_id: @account.id,
                                                    **lines_attrs }])
  end

  test "a line's site comes from its equipment, then the PO ship-to" do
    with_equipment = expense_po(equipment_id: @capper.id).line_items.first
    assert_equal @shop, with_equipment.location
    assert_equal '0005-6150-01', with_equipment.gl_account_code

    plain = expense_po.line_items.first
    assert_equal @plant, plain.location
  end

  test 'expense lines carry no product and need a description' do
    po = expense_po(product_id: 'SOMETHING')
    assert_nil po.line_items.first.product_id

    po.line_items.build(quantity: 1, unit_cost: 5)
    assert_not po.valid?
    assert_includes po.errors[:base], 'Each expense line needs a description'
  end

  test 'approval needs a GL account on every line' do
    po = expense_po(expense_account_id: nil)
    error = assert_raises(ArgumentError) { po.approve!(nil) }
    assert_match(/Chuck insert: needs a GL account/, error.message)

    po.line_items.first.update!(expense_account: @account)
    po.reload.approve!(nil)
    assert_equal 'approved', po.status
  end

  test 'submitting goes nowhere near PDI, and it never posts to inventory' do
    po = expense_po
    po.approve!(nil)
    assert_no_enqueued_jobs(only: PdiExportJob) { po.update!(status: 'submitted', submitted_at: Time.current) }

    po.mark_received!(nil)
    assert_not po.postable?
    assert_raises(ArgumentError) { po.post_to_inventory!(nil) }
  end

  test 'inventory POs still export to PDI on submit' do
    po = PurchaseOrder.create!(vendor: @vendor, location: @plant, status: 'approved')
    assert_enqueued_jobs(1, only: PdiExportJob) { po.update!(status: 'submitted') }
  end

  test 'accounts and equipment in use cannot be deleted' do
    expense_po(equipment_id: @capper.id)
    assert_not @account.destroy
    assert_not @capper.destroy
  end
end
