require 'test_helper'

class PdiInvoiceDateImportServiceTest < ActiveSupport::TestCase
  fixtures :locations, :location_categories

  def csv(text)
    Tempfile.new(['inv', '.csv']).tap do |file|
      file.write(text)
      file.close
    end.path
  end

  def order(number, **attrs)
    CustomerOrder.create!(external_order_no: number, order_status: 'billed', location: locations(:terminal), **attrs)
  end

  test 'fills invoice details by PDI order number, columns found by header name' do
    a = order('OD-1')
    b = order('OD-2', invoice_no: 'KEEP', invoice_date: Date.new(2026, 1, 1))
    path = csv(<<~CSV)
      Salesperson,InvoiceDate,OrderNo,InvoiceNo
      Pat,2026-10-03 00:00:00,OD-1,INV1
      NULL,10/05/2026,OD-2,NULL
      ,2026-10-01,OD-404,X
      ,garbage,OD-1,Y
    CSV
    service = PdiInvoiceDateImportService.new(path)

    assert_equal [3, 2, 2, 1, 1], service.summary.to_h.values_at(:rows, :matched, :changes, :not_found, :bad_dates)
    assert_equal 2, service.import!
    assert_equal [Date.new(2026, 10, 3), 'INV1', 'Pat'], a.reload.values_at(:invoice_date, :invoice_no, :salesperson)
    assert_equal [Date.new(2026, 10, 5), 'KEEP'], b.reload.values_at(:invoice_date, :invoice_no)
    assert_equal 0, PdiInvoiceDateImportService.new(path).import!, 'nothing left to change'
  end

  test 'a file without order number or invoice date columns is refused' do
    assert_raises(ArgumentError) { PdiInvoiceDateImportService.new(csv("Foo,Bar\n1,2\n")).rows }
  end
end
