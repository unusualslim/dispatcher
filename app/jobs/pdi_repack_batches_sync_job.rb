# Nightly repack batches from the PDI SQL export (FPS_REPACK_BATCHES_<date>.csv, the last 90 days, with a header
# row; query in docs/pdi_sql/repack_batches.sql). Runs the same import as Data Imports → Repack Batches: new
# batches become production orders, and an order with no warehouse gets it from PDI's Warehouse_ID.
# See PdiCsvPickup.
class PdiRepackBatchesSyncJob < ApplicationJob
  include PdiCsvPickup

  PROCESS_NAME = 'PDI Repack Batches Sync'.freeze
  FILE_PREFIX  = 'FPS_REPACK_BATCHES'.freeze

  private

  def import(path)
    result = RepackBatchImportService.call(path)
    { created: result.created, updated: result.warehouse_set,
      skipped: result.skipped_exists + result.skipped_reversed + result.skipped_no_product,
      warnings: result.errors }
  end
end
