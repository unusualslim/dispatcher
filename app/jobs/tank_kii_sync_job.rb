# Kii's hourly tank report (KII_<day>_<HH>.csv, staged to FTP /Imports by docs/tank_feeds/Kii_WinSCP_Launch.bat).
class TankKiiSyncJob < ApplicationJob
  include TankFeedPickup

  PROCESS_NAME = 'Kii Tank Sync'.freeze
  FILE_PREFIX = 'KII'.freeze
  FEED = 'kii'.freeze
end
