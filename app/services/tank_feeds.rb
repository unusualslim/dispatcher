require 'csv'

# Tank feed importers: each parses one feed's file into Rows, then #import! stores them. A feed tank seen for the
# first time is created (ignored when the feed says it isn't ours); readings of ignored feed tanks are skipped, and
# a reading already stored (same feed tank and time) is a duplicate, so files can be imported again safely.
module TankFeeds
  Row = Struct.new(:external_id, :name, :read_at, :gallons, :water_inches, :temperature_f, :status, :details,
                   :default_ignored, keyword_init: true) do
    def readable?
      read_at.present? && gallons.present?
    end
  end

  Summary = Struct.new(:rows, :feed_tanks, :new_feed_tanks, :ignored, :new_readings, :duplicates, :newest_read_at,
                       :unreadable, keyword_init: true)

  FEED_CLASSES = { 'kii' => 'TankFeeds::Kii', 'smartank' => 'TankFeeds::Smartank', 'plant_0002' => 'TankFeeds::Plant0002',
                   'spreadsheet' => 'TankFeeds::SpreadsheetHistory' }.freeze

  def self.for(feed, path, **options)
    FEED_CLASSES.fetch(feed).constantize.new(path, **options)
  end
end
