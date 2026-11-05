require 'test_helper'

# The nightly PDI SQL export pickups: FPS_*.csv files on the PDI FTP, oldest first, deleted once imported.
class PdiCsvPickupTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories, :vendors

  # Just enough of Net::FTP for the jobs.
  class FakeFtp
    attr_reader :files, :deleted

    def initialize(files)
      @files = files
      @deleted = []
    end

    def chdir(_dir) = nil
    def nlst = files.keys

    def delete(name)
      files.delete(name)
      deleted << name
    end

    def retrbinary(cmd, _size)
      yield files.fetch(cmd.delete_prefix('RETR '))
    end
  end

  def run_job(job_class, ftp)
    job = job_class.new
    job.define_singleton_method(:ftp_connect) { |&block| block.call(ftp) }
    job.perform_now
  end

  def order(number)
    CustomerOrder.create!(external_order_no: number, order_status: 'billed', location: locations(:terminal))
  end

  test 'invoice dates: imports each waiting file oldest first, logs it and deletes it' do
    a = order('OD-1')
    ftp = FakeFtp.new(
      'FPS_INVOICE_DATES_20261105.csv' => "OrderNo,InvoiceDate,InvoiceNo\nOD-1,2026-11-04,INV-2\n",
      'FPS_INVOICE_DATES_20261104.csv' => "OrderNo,InvoiceDate,InvoiceNo\nOD-1,2026-11-03,INV-1\nOD-9,2026-11-03,X\n",
      'AP Vendor List.csv' => 'not ours'
    )

    run_job(PdiInvoiceDatesSyncJob, ftp)

    assert_equal ['AP Vendor List.csv'], ftp.files.keys, 'only our files are taken'
    assert_equal %w[FPS_INVOICE_DATES_20261104.csv FPS_INVOICE_DATES_20261105.csv], ftp.deleted
    assert_equal [Date.new(2026, 11, 4), 'INV-2'], a.reload.values_at(:invoice_date, :invoice_no)
    logs = SyncLog.where(process_name: 'PDI Invoice Dates Sync').order(:id)
    assert_equal %w[success success], logs.map(&:status)
    assert_match(/1 orders not in the app/, logs.first.warnings)
    assert_includes logs.last.file_content, 'INV-2'
  end

  test 'a file that fails stays on FTP for the next run' do
    ftp = FakeFtp.new('FPS_INVOICE_DATES_20261105.csv' => "Nope,Columns\n1,2\n")

    run_job(PdiInvoiceDatesSyncJob, ftp)

    assert_equal ['FPS_INVOICE_DATES_20261105.csv'], ftp.files.keys
    log = SyncLog.find_by!(process_name: 'PDI Invoice Dates Sync')
    assert_equal 'failed', log.status
    assert_match(/Couldn't find/, log.error_message)
  end

  test 'no waiting file is logged as skipped' do
    run_job(PdiPoLinesSyncJob, FakeFtp.new({}))

    assert_equal 'skipped', SyncLog.find_by!(process_name: 'PDI PO Lines Sync').status
  end

  test 'PO lines: the header-less 56-column file creates the PO' do
    values = { 0 => 'key-FPS3001', 1 => 'FPS3001', 3 => vendors(:chem_supply).id.to_s, 4 => 'Chem Supply',
               9 => 'Entered', 12 => '2026-11-01 00:00:00', 33 => 'line-1', 34 => '110',
               36 => products(:urea).id, 37 => 'Urea', 41 => '100', 46 => '1.25' }
    row = Array.new(56) { |i| values.fetch(i, 'NULL') }
    ftp = FakeFtp.new('FPS_PO_LINES_20261105.csv' => row.to_csv)

    run_job(PdiPoLinesSyncJob, ftp)

    assert PurchaseOrder.exists?(pdi_reference: 'FPS3001')
    assert_equal ['FPS_PO_LINES_20261105.csv'], ftp.deleted
    log = SyncLog.find_by!(process_name: 'PDI PO Lines Sync')
    assert_equal [1, 'success'], log.values_at(:records_created, :status)
  end

  test 'file names other FTP jobs use are never matched' do
    %w[orders.xls AP_Vendor_List.csv FI_Inventory_Report.csv FPS_PO_LINES.xls FPS_PO_LINESX.csv].each do |name|
      assert_not PdiPoLinesSyncJob.matches?(name), name
    end
    assert PdiPoLinesSyncJob.matches?('fps_po_lines-2026-11-05.csv')
    assert PdiInvoiceDatesSyncJob.matches?('FPS_INVOICE_DATES.csv')
  end
end
