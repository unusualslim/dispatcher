# Scheduled: posts any completed production orders whose FPST journal is now ready, then sends all
# pending ledger entries to PDI in one file. Quietly does nothing when there's nothing to send.
class PdiGlExportJob < ApplicationJob
  queue_as :default

  def perform
    ProductionGlPosting.post_ready_orders!
    PdiGlExport.new.run
  rescue PdiGlExport::NothingToExport
    nil
  end
end
