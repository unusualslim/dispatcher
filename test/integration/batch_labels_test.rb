require 'test_helper'

class BatchLabelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    product = Product.create!(id: 'BLT-DEF25', name: 'DEF 2.5 gal x2')
    warehouse = Location.create!(company_name: 'BLT Plant', pdi_site_code: '0110', location_category_id: 1)
    @order = ProductionOrder.create!(number: 'BLT-1', product: product, location: warehouse, status: 'completed',
                                     lot_number: 'FPS-DEF25G-20261112-001', batch_number: 'PDI-7788',
                                     date_completed: Date.new(2026, 11, 12), total_qty_produced: 240)
    @admin = User.create!(email: 'batch-labels-admin@example.com', password: 'password123', role: 'admin')
  end

  test 'prints full 4x6 batch labels with product, made date, lot, PDI batch and a QR to the lot page' do
    sign_in @admin
    get production_order_path(@order)
    assert_select "a[href='#{batch_labels_production_order_path(@order)}']", text: /Batch Labels/

    get batch_labels_production_order_path(@order, count: 3)
    assert_response :success
    assert_select 'section.page.full', 3
    assert_select '.full .product', text: 'DEF 2.5 gal x2'
    assert_select '.full .made .v', text: '11/12/2026'
    assert_select '.full .lot .v', text: 'FPS-DEF25G-20261112-001'
    assert_select '.full .row .v', text: 'PDI-7788'
    assert_select ".qr[data-qr='#{lot_scan_url(lot: @order.lot_number)}']", 3
    assert_select '.pallet', text: '3 of 3'
  end

  test 'four small labels per 4x6 page' do
    sign_in @admin
    get batch_labels_production_order_path(@order, count: 6, format_type: 'quad')
    assert_select 'section.page.quad', 2
    assert_select '.mini:not(.blank)', 6
    assert_select '.mini.blank', 2
    assert_select '.mini .made', text: '11/12/2026'
  end

  test 'a typed note prints on full and quad labels' do
    sign_in @admin
    get batch_labels_production_order_path(@order, count: 2, note: 'Ship to Albany first')
    assert_select '.full .notes:not([hidden]) [data-note]', text: 'Ship to Albany first', count: 2

    get batch_labels_production_order_path(@order, count: 2, format_type: 'quad', note: 'x' * 500)
    assert_select '.mini .note [data-note]', text: 'x' * BatchLabel::NOTE_LIMIT, count: 2

    get batch_labels_production_order_path(@order)
    assert_select '.full .notes[hidden]', 1
  end

  test 'no labels until the order has a lot number' do
    sign_in @admin
    @order.update!(lot_number: nil)
    get batch_labels_production_order_path(@order)
    assert_redirected_to production_order_path(@order)
  end

  test 'crew without an account needs the batch label password to open a scanned lot' do
    get lot_scan_path(lot: @order.lot_number)
    assert_redirected_to gate_path(return_to: lot_scan_path(lot: @order.lot_number))

    with_batch_password('crew-pass') do
      post gate_path, params: { password: 'crew-pass', return_to: lot_scan_path(lot: @order.lot_number) }
    end
    assert_redirected_to lot_scan_path(lot: @order.lot_number)
    follow_redirect!
    assert_response :success
    assert_select 'div', text: 'DEF 2.5 gal x2'
    assert_select 'div', text: '11/12/2026'
    assert_select 'dd', text: 'PDI-7788'
    assert_select 'a', text: 'Open production order', count: 0
  end

  test 'signed-in users skip the password and get a link to the order; voided and unknown lots' do
    sign_in @admin
    get lot_scan_path(lot: @order.lot_number)
    assert_response :success
    assert_select "a[href='#{production_order_path(@order)}']", text: 'Open production order'

    @order.update!(status: 'voided', voided_at: Time.current)
    get lot_scan_path(lot: @order.lot_number)
    assert_select '.alert-danger', text: /voided/

    get lot_scan_path(lot: 'NOPE-1')
    assert_response :not_found
  end

  private

  def with_batch_password(password)
    old = ENV.fetch('BATCH_QR_PASSWORD', nil)
    ENV['BATCH_QR_PASSWORD'] = password
    yield
  ensure
    ENV['BATCH_QR_PASSWORD'] = old
  end
end
