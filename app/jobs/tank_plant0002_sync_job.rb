# Site 0002's tank email (FPS_TANKS_0002_<yyyyMMdd>_<HHmm>.txt, saved to FTP /Imports by Power Automate). The
# reading time is the name's stamp (Eastern).
class TankPlant0002SyncJob < ApplicationJob
  include TankFeedPickup

  PROCESS_NAME = '0002 Tank Email Sync'.freeze
  FILE_PREFIX = 'FPS_TANKS_0002'.freeze
  FILE_EXT = 'txt'.freeze
  FEED = 'plant_0002'.freeze
end
