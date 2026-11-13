require 'test_helper'

class IncomingReceiptsTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories, :vendors

  TODAY = Date.new(2026, 11, 13)

  setup do
    @main = locations(:warehouse)
    @south = locations(:terminal)
    @vendor = vendors(:chem_supply)
  end

  def purchase_order(status:, expected:, location:, reference: nil, carrier: nil)
    order = PurchaseOrder.create!(vendor: @vendor, location: location, status: status, expected_delivery_date: expected,
                                  pdi_reference: reference, freight_vendor: carrier)
    order.line_items.create!(product: products(:urea), quantity: 40, unit_cost: 2, package_code: 'GA')
    order
  end

  def report(params = {})
    travel_to(TODAY) { Reports::IncomingReceipts.new(params, today: TODAY).rows }
  end

  test 'lists ordered POs by location then date with vendor and carrier, undated last' do
    carrier = Vendor.create!(id: 'CARR-1', name: 'Hauler')
    purchase_order(status: 'submitted', expected: TODAY + 5, location: @main, reference: 'A-LATE')
    purchase_order(status: 'approved', expected: TODAY + 1, location: @main, reference: 'A-SOON', carrier: carrier)
    purchase_order(status: 'submitted', expected: nil, location: @main, reference: 'A-NODATE')
    purchase_order(status: 'submitted', expected: TODAY + 2, location: @south, reference: 'B-ONE')

    rows = report

    assert_equal 4, rows.size
    main_rows = rows.select { |r| r[:location] == @main.company_name }
    assert_equal %w[A-SOON A-LATE A-NODATE], main_rows.pluck(:po_no)
    assert_equal ['Hauler (CARR-1)', nil, nil], main_rows.pluck(:carrier)
    assert_equal [1, 5, nil], main_rows.pluck(:days)
    assert_equal @vendor.label, rows.first[:vendor]
    assert_equal ['B-ONE'], rows.select { |r| r[:location] == @south.company_name }.pluck(:po_no)
  end

  test 'leaves out drafts, received and voided POs and dates outside the window' do
    purchase_order(status: 'draft', expected: TODAY + 1, location: @main, reference: 'DRAFT')
    purchase_order(status: 'received', expected: TODAY + 1, location: @main, reference: 'RECEIVED')
    purchase_order(status: 'submitted', expected: TODAY + 30, location: @main, reference: 'FAR')
    purchase_order(status: 'submitted', expected: TODAY - 20, location: @main, reference: 'OLD')
    purchase_order(status: 'submitted', expected: TODAY - 3, location: @main, reference: 'OVERDUE')
    voided = purchase_order(status: 'submitted', expected: TODAY + 1, location: @main, reference: 'VOIDED')
    voided.update!(voided_at: Time.current)

    assert_equal ['OVERDUE'], report.pluck(:po_no)
    assert_equal [-3], report.pluck(:days)
  end

  test 'filters by location and vendor' do
    purchase_order(status: 'submitted', expected: TODAY + 1, location: @main, reference: 'MAIN')
    purchase_order(status: 'submitted', expected: TODAY + 1, location: @south, reference: 'SOUTH')

    assert_equal ['SOUTH'], report(location_id: @south.id.to_s).pluck(:po_no)
    assert_empty report(vendor_id: 'NOBODY')
  end
end
