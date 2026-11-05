# Nightly PO lines from the PDI SQL export (FPS_PO_LINES_<date>.csv: the 56-column, header-less layout of
# Data Imports → PDI Purchase Orders). See PdiCsvPickup.
class PdiPoLinesSyncJob < ApplicationJob
  include PdiCsvPickup

  PROCESS_NAME = 'PDI PO Lines Sync'.freeze
  FILE_PREFIX  = 'FPS_PO_LINES'.freeze

  private

  def import(path)
    result = PdiPurchaseOrderImportService.call(path)
    { created: result.created, updated: result.updated,
      skipped: result.skipped_exists + result.skipped_no_vendor,
      warnings: result.errors + (result.received.positive? ? ["#{result.received} received into inventory"] : []) }
  end
end
