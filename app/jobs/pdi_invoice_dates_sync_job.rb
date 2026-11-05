# Nightly invoice dates from the PDI SQL export (FPS_INVOICE_DATES_<date>.csv, with a header row: order number,
# invoice date, optional invoice # and salesperson; the layout of Data Imports → PDI Invoice Dates).
# See PdiCsvPickup.
class PdiInvoiceDatesSyncJob < ApplicationJob
  include PdiCsvPickup

  PROCESS_NAME = 'PDI Invoice Dates Sync'.freeze
  FILE_PREFIX  = 'FPS_INVOICE_DATES'.freeze

  private

  def import(path)
    service = PdiInvoiceDateImportService.new(path)
    summary = service.summary
    updated = service.import!
    warnings = []
    warnings << "#{summary.not_found} orders not in the app" if summary.not_found.positive?
    warnings << "#{summary.bad_dates} rows with an unreadable invoice date" if summary.bad_dates.positive?
    { created: 0, updated: updated, skipped: summary.rows - summary.changes, warnings: warnings }
  end
end
