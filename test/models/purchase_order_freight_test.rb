require 'test_helper'

class PurchaseOrderFreightTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    @vendor = Vendor.create!(id: 'POF-V', name: 'POF Vendor')
    @carrier = Vendor.create!(id: 'POF-C', name: 'POF Carrier')
    @warehouse = Location.create!(company_name: 'POF Warehouse', location_category_id: 1)
    @a = Product.create!(id: 'POF-A', name: 'POF A')
    @b = Product.create!(id: 'POF-B', name: 'POF B')
    @po = PurchaseOrder.create!(vendor: @vendor, location: @warehouse, status: 'received', freight_amount: 100,
                                freight_allocation: 'quantity', received_at: Time.current)
    @line_a = @po.line_items.create!(product: @a, quantity: 30, unit_cost: 10)
    @line_b = @po.line_items.create!(product: @b, quantity: 10, unit_cost: 50)
  end

  test 'freight spreads by quantity or by value into landed cost' do
    assert_equal({ @line_a.id => 75.to_d, @line_b.id => 25.to_d }, @po.freight_allocations)
    assert_equal 12.5.to_d, @po.landed_unit_cost(@line_a)

    @po.freight_allocation = 'value' # 300 vs 500
    assert_equal({ @line_a.id => 37.5.to_d, @line_b.id => 62.5.to_d }, @po.freight_allocations)
  end

  test 'no allocation method leaves line cost alone (PDI history)' do
    @po.freight_allocation = nil
    assert_empty @po.freight_allocations
    assert_equal 10, @po.landed_unit_cost(@line_a)
  end

  test 'receipts post at landed cost' do
    @po.post_to_inventory!(nil)
    txn = InventoryTransaction.find_by(transactable: @po, product_id: @a.id)
    assert_equal 12.5.to_d, txn.unit_cost
  end

  test 'a separate carrier accrues a payable that the invoice turns into invoiced' do
    @po.update!(freight_source: 'carrier', freight_vendor: @carrier, freight_accrued: true, freight_bol: 'BOL-1')
    payable = @po.sync_freight_payable!
    assert_equal ['accrued', 100.to_d, 'BOL-1'], [payable.status, payable.accrued_amount, payable.bol_number]

    payable.update!(invoice_no: 'INV-7', amount: 110, invoice_date: Date.current)
    assert_equal 'invoiced', payable.status
    assert_equal 10.to_d, payable.variance

    @po.update!(freight_source: 'vendor_invoice')
    @po.sync_freight_payable!
    assert FreightPayable.exists?(payable.id), 'an invoiced payable is kept'
  end
end
