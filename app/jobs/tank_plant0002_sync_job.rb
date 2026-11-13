# Site 0002's tank email, saved whole to FTP /Imports by Power Automate as FPS_TANKS_0002_<anything>.eml (the
# reading time is the email's Date header, Eastern). A text file of the lines, FPS_TANKS_0002_<yyyyMMdd>_<HHmm>.txt
# (time from the name), is still read too.
class TankPlant0002SyncJob < ApplicationJob
  include TankFeedPickup

  PROCESS_NAME = '0002 Tank Email Sync'.freeze
  FILE_PREFIX = 'FPS_TANKS_0002'.freeze
  FILE_EXT = 'eml|txt'.freeze
  FEED = 'plant_0002'.freeze
end
