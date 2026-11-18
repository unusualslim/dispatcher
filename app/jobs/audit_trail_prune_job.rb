# Scheduled (weekly): deletes audit trail versions older than 5 years, the retention Lance set (17 Nov 2026).
class AuditTrailPruneJob < ApplicationJob
  PROCESS_NAME = 'Audit Trail Cleanup'.freeze
  KEEP = 5.years

  queue_as :default

  def perform
    PaperTrail::Version.where(created_at: ...KEEP.ago).in_batches(of: 5_000).delete_all
  end
end
