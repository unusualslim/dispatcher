require 'test_helper'

class PdiPurchaseOrderImportServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  fixtures :products, :locations, :location_categories, :vendors

  setup do
    AppSetting.set(InventoryRevaluation::START_DATE_KEY, '2026-10-01')
    @south = locations(:warehouse).tap { |l| l.update!(pdi_site_code: '0110') }
    @product = products(:urea)
    LocationProduct.where(product: @product).delete_all
  end

  # One PO line in PDI's 56-column layout (no header). opts: site, received, qty, cost.
  def line(po_no, status, **opts)
    opts = { site: '110', received: '2026-10-20 10:00:00', qty: '100', cost: '1.25' }.merge(opts)
    values = { 0 => "key-#{po_no}", 1 => po_no, 3 => vendors(:chem_supply).id.to_s, 4 => 'Chem Supply', 9 => status,
               12 => '2026-10-01 00:00:00', 15 => '2026-10-19 00:00:00', 18 => opts[:received],
               33 => "line-#{po_no}", 34 => opts[:site], 36 => @product.id, 37 => 'Urea', 41 => opts[:qty],
               43 => opts[:qty], 46 => opts[:cost] }
    Array.new(56) { |i| values.fetch(i, 'NULL') }
  end

  def import(*rows)
    file = Tempfile.new(['pos', '.csv'])
    file.write(rows.map(&:to_csv).join)
    file.close
    PdiPurchaseOrderImportService.call(file.path)
  end

  def on_hand
    LocationProduct.find_by(location: @south, product: @product)&.quantity.to_f
  end

  test 'a PO received since tracking began goes into inventory at its line cost' do
    result = import(line('FPS2001', 'Invoiced'))

    assert_equal [1, 1], [result.created, result.received]
    assert_equal 100.0, on_hand
    receipt = InventoryTransaction.find_by!(movement_type: 'receipt')
    assert_equal [125.0, Date.new(2026, 10, 20)], [receipt.total_cost.to_f, receipt.occurred_on]
    assert PurchaseOrder.find_by!(pdi_reference: 'FPS2001').posted?
  end

  test 'an ordered PO updates when PDI receives it, without sending it back to PDI' do
    import(line('FPS2002', 'Entered', received: 'NULL'))
    assert_no_enqueued_jobs(only: PdiExportJob) { import(line('FPS2002', 'Ordered', received: 'NULL', qty: '80')) }
    po = PurchaseOrder.find_by!(pdi_reference: 'FPS2002')
    assert_equal ['submitted', 80], [po.status, po.line_items.first.quantity.to_i]

    result = import(line('FPS2002', 'Invoiced', qty: '90'))
    assert_equal [1, 1], [result.updated, result.received]
    assert_equal 90.0, on_hand

    assert_equal 1, import(line('FPS2002', 'Invoiced')).skipped_exists, 'in inventory: left alone'
  end

  test 'freight entered in the app survives a refresh and lands into the receipt cost' do
    import(line('FPS2005', 'Ordered', received: 'NULL'))
    po = PurchaseOrder.find_by!(pdi_reference: 'FPS2005')
    po.update!(freight_amount: 30, freight_allocation: 'quantity', freight_source: 'carrier',
               freight_vendor_id: vendors(:chem_supply).id, freight_accrued: true)
    po.sync_freight_payable!

    import(line('FPS2005', 'Ordered', received: 'NULL'))
    assert_equal 30, po.reload.freight_amount.to_i, 'PDI freight-on-invoice does not overwrite it'

    import(line('FPS2005', 'Invoiced'))
    receipt = InventoryTransaction.find_by!(movement_type: 'receipt')
    assert_equal 155.0, receipt.total_cost.to_f, '100 × 1.25 + 30 freight'
    assert_equal 30, po.freight_payable.accrued_amount.to_i
  end

  test 'PDI freight still refreshes on POs without app freight' do
    import(line('FPS2006', 'Ordered', received: 'NULL'))
    PurchaseOrder.find_by!(pdi_reference: 'FPS2006').update!(freight_amount: 12)

    import(line('FPS2006', 'Ordered', received: 'NULL'))
    assert_equal 0, PurchaseOrder.find_by!(pdi_reference: 'FPS2006').freight_amount.to_i
  end

  test 'older and dropship POs are only marked posted' do
    import(line('FPS2003', 'Invoiced', received: '2026-09-15 10:00:00'), line('FPS2004', 'Invoiced', site: '7777'))

    assert_equal 0.0, on_hand
    assert_empty InventoryTransaction.where(movement_type: 'receipt')
    assert PurchaseOrder.where(pdi_reference: %w[FPS2003 FPS2004]).all?(&:posted?)
    dropship = PurchaseOrder.find_by!(pdi_reference: 'FPS2004')
    dropship.update!(posted_at: nil)
    assert_not dropship.postable?
    assert_raises(ArgumentError) { dropship.post_to_inventory!(nil) }
  end

  test 'POs match on PDI key, so PDI POs can share a number' do
    first = line('TODD', 'Ordered', received: 'NULL')
    second = line('TODD', 'Ordered', received: 'NULL').tap { |row| row[0] = 'key-other' }

    assert_equal [2, []], import(first, second).to_h.values_at(:created, :errors)
    assert_equal [2, 0], import(first, second).to_h.values_at(:updated, :created)
    assert_equal %w[key-TODD key-other], PurchaseOrder.where(pdi_reference: 'TODD').order(:id).pluck(:pdi_po_key)
  end

  test 'a PO imported before keys were stored is matched once by number' do
    old = PurchaseOrder.create!(vendor: vendors(:chem_supply), pdi_reference: 'LP', status: 'submitted',
                                trigger_type: 'pdi_import')
    rows = [line('LP', 'Ordered', received: 'NULL'), line('LP', 'Ordered', received: 'NULL').tap { |r| r[0] = 'k2' }]

    assert_equal [1, 1], import(*rows).to_h.values_at(:updated, :created)
    assert_equal 'key-LP', old.reload.pdi_po_key
  end

  test 'numberless POs received before tracking began are not imported again' do
    old = line('NULL', 'Invoiced', received: '2023-05-01 10:00:00').tap { |row| row[0] = 'key-9' }

    assert_equal [0, 1], import(old).to_h.values_at(:created, :skipped_exists)
  end

  test 'vendors match on PDI ID; PDI vendors can share a name' do
    Vendor.create!(id: '1571', name: 'KM Solutions, LLC')
    row = line('FPS2005', 'Ordered', received: 'NULL').tap do |r|
      r[3] = '1570'
      r[4] = 'KM Solutions, LLC'
    end

    assert_equal 1, import(row).created
    vendor = PurchaseOrder.find_by!(pdi_reference: 'FPS2005').vendor
    assert_equal ['1570', 'KM Solutions, LLC (1570)'], [vendor.id, vendor.label]
  end
end
