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

  test 'repack batches: a new batch becomes an order and a later file fills a missing warehouse' do
    main = locations(:warehouse).tap { |l| l.update!(pdi_site_code: '0002') }
    batch = lambda do |warehouse_id, name|
      row = Array.new(40)
      { 0 => '15300', 1 => 'Repack', 2 => '2026-11-05', 3 => 'Unposted', 8 => warehouse_id, 9 => name,
        13 => products(:urea).id, 16 => '10' }.each { |i, v| row[i] = v }
      "Batch_Key,Batch_Description\n#{row.to_csv}"
    end

    run_job(PdiRepackBatchesSyncJob, FakeFtp.new('FPS_REPACK_BATCHES_20261105.csv' => batch.call('9999', 'Nowhere')))
    order = ProductionOrder.find_by!(number: 'PDI-15300')
    assert_nil order.location
    first_log = SyncLog.find_by!(process_name: 'PDI Repack Batches Sync')
    assert_equal [1, 'success'], first_log.values_at(:records_created, :status)
    assert_match(/Batch 15300: warehouse 9999 Nowhere matches no location/, first_log.warnings)

    run_job(PdiRepackBatchesSyncJob, FakeFtp.new('FPS_REPACK_BATCHES_20261106.csv' => batch.call('2', 'FPS-Main')))
    assert_equal main, order.reload.location
    assert_equal 1, SyncLog.where(process_name: 'PDI Repack Batches Sync').order(:id).last.records_updated
  end

  test 'a run that finds another run of the same process working leaves the files alone' do
    ftp = FakeFtp.new('FPS_INVOICE_DATES_20261105.csv' => "OrderNo,InvoiceDate\nOD-1,2026-11-04\n")
    key = Zlib.crc32(PdiInvoiceDatesSyncJob::PROCESS_NAME)
    # A second database session, as a second run would have (tests share one pooled connection, so open our own).
    info = ActiveRecord::Base.connection.raw_connection.conninfo_hash
    other = PG.connect(info.compact.slice(:host, :port, :dbname, :user, :password))
    begin
      other.exec("SELECT pg_advisory_lock(#{key.to_i})")
      run_job(PdiInvoiceDatesSyncJob, ftp)

      assert_equal ['FPS_INVOICE_DATES_20261105.csv'], ftp.files.keys, 'the file waits for the run that holds it'
      assert_equal 'skipped', SyncLog.find_by!(process_name: 'PDI Invoice Dates Sync').status
      assert_match(/Another run/, SyncLog.find_by!(process_name: 'PDI Invoice Dates Sync').error_message)
    ensure
      other.exec("SELECT pg_advisory_unlock(#{key.to_i})")
      other.close
    end

    run_job(PdiInvoiceDatesSyncJob, ftp)
    assert_empty ftp.files, 'once the other run is done, the next run takes the file'
  end

  test 'the lock is released after a run, so the next run works' do
    run_job(PdiPoLinesSyncJob, FakeFtp.new({}))
    run_job(PdiPoLinesSyncJob, FakeFtp.new({}))

    assert_equal %w[skipped skipped], SyncLog.where(process_name: 'PDI PO Lines Sync').order(:id).map(&:status)
    assert_empty SyncLog.where(process_name: 'PDI PO Lines Sync').where("error_message LIKE 'Another run%'")
  end
end
