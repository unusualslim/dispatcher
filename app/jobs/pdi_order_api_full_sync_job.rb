# Nightly: every open order and the last week's finished ones from PDI (PdiOrders::Feed :full), then
# asks PDI the status of open app orders it didn't send (PdiOrders::StatusCheck). Catches anything the
# 15-minute changes sync (PdiOrderApiSyncJob) missed.
class PdiOrderApiFullSyncJob < PdiOrderApiSyncJob
  PROCESS_NAME = 'PDI Order API Full Sync'.freeze
  MODE = :full
end
