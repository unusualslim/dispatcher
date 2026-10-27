# Scheduled: posts any completed production orders whose FPST journal is now ready and pending inventory
# movements of categories the app posts (InventoryGlPosting), then sends all pending ledger entries to PDI
# in one file. Quietly does nothing when there's nothing to send.
class PdiGlExportJob < ApplicationJob
  queue_as :default

  def perform
    ProductionGlPosting.post_ready_orders!
    InventoryGlPosting.post_pending!
    PdiGlExport.new.run
  rescue PdiGlExport::NothingToExport
    nil
  end
end
