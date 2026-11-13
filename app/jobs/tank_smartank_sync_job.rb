# Smartank's daily tank report (FPS_SMARTANK_<yyyyMMdd>_<HHmm>.csv, saved to FTP /Imports by Power Automate).
class TankSmartankSyncJob < ApplicationJob
  include TankFeedPickup

  PROCESS_NAME = 'Smartank Tank Sync'.freeze
  FILE_PREFIX = 'FPS_SMARTANK'.freeze
  FEED = 'smartank'.freeze
end
