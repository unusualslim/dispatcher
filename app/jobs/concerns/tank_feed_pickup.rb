# FTP pickup for a tank feed (see PdiCsvPickup): each file's readings are linked to its SyncLog. Feeds that send
# a file every hour (Kii) clear the stored file from SyncLogs older than KEEP_FILES_DAYS, keeping the log rows.
module TankFeedPickup
  extend ActiveSupport::Concern
  include PdiCsvPickup

  KEEP_FILES_DAYS = 14
  MIN_FILE_AGE = 2.minutes

  # Admin → Automated Processes entries; all start Off until the tanks are set up.
  AUTOMATED_PROCESSES = [
    { slug: 'tank-kii-sync', name: 'Kii Tank Sync', job: 'TankKiiSyncJob', default_schedule: '',
      description: 'Kii tank readings: every KII_*.csv waiting on PDI FTP /Imports (hourly reports). ' \
                   'Off until tanks are set up (Dispatch → Tank Feeds).' },
    { slug: 'tank-smartank-sync', name: 'Smartank Tank Sync', job: 'TankSmartankSyncJob', default_schedule: '',
      description: 'Smartank tank readings: every FPS_SMARTANK_*.csv waiting on PDI FTP /Imports (daily report ' \
                   'via Power Automate). Off until tanks are set up.' },
    { slug: 'tank-plant-0002-sync', name: '0002 Tank Email Sync', job: 'TankPlant0002SyncJob', default_schedule: '',
      description: 'Site 0002 Bulk DEF tank levels: every FPS_TANKS_0002_*.txt waiting on PDI FTP /Imports ' \
                   '(tank email via Power Automate). Off until tanks are set up.' }
  ].freeze

  def perform
    super
    SyncLog.where(process_name: self.class::PROCESS_NAME, started_at: ...KEEP_FILES_DAYS.days.ago)
           .where.not(file_content: nil).update_all(file_content: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def import(path)
    TankFeeds.for(self.class::FEED, path, file_name: current_file).import!(sync_log: current_log)
  end
end
