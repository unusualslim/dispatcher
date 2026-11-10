# Nightly PDI freight in detail from the PDI SQL export (FPS_FREIGHT_DETAIL_<date>.csv, docs/pdi_sql/
# freight_detail.sql): the rules behind each fuel line's freight, so the freight reports can show FPLFSC, TAFSC…
# on their own lines. See PdiCsvPickup.
class PdiFreightDetailSyncJob < ApplicationJob
  include PdiCsvPickup

  PROCESS_NAME = 'PDI Freight Detail Sync'.freeze
  FILE_PREFIX  = 'FPS_FREIGHT_DETAIL'.freeze

  private

  def import(path)
    result = PdiFreightComponents::Import.call(path)
    { created: result.created, updated: 0, skipped: result.skipped, warnings: result.warnings }
  end
end
