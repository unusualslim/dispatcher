# A tank as one feed knows it: a Kii sensor, a Smartank tank, a line of the 0002 tank email, a tab of the old
# spreadsheet, or a tank's manual readings. Mapped to an app Tank on Dispatch → Tanks; until then (and while not
# ignored) it waits under "New feed tanks". Ignored feed tanks keep updating their details but store no readings.
class FeedTank < ApplicationRecord
  FEEDS = {
    'kii' => 'Kii',
    'smartank' => 'Smartank',
    'plant_0002' => '0002 tank email',
    'spreadsheet' => 'Spreadsheet history',
    'manual' => 'Manual reading'
  }.freeze

  belongs_to :tank, optional: true
  has_many :readings, class_name: 'TankReading', dependent: :delete_all

  validates :feed, inclusion: { in: FEEDS.keys }
  validates :external_id, presence: true, uniqueness: { scope: :feed }

  scope :needs_setup, -> { where(tank_id: nil, ignored: false) }
  scope :in_feed, ->(feed) { where(feed: feed) }

  # Hours without a reading before a tank shows as stale.
  def self.stale_hours
    AppSetting.get('tank_stale_hours').to_i.nonzero? || 30
  end

  def feed_name
    FEEDS[feed]
  end

  def label
    "#{feed_name}: #{name.presence || external_id}"
  end

  # The feed's latest name and details (location, product, capacity…), saved when they changed.
  def absorb(name:, details:)
    self.name = name if name.present?
    self.details = self.details.merge(details.to_h.compact_blank.stringify_keys)
    save! if changed?
  end

  # Stores a reading once (same tank and time again is a duplicate) and keeps the latest one on the feed tank.
  # reading: read_at, gallons (+ water_inches, temperature_f, status). Returns :created or :duplicate.
  def record_reading!(reading, sync_log: nil)
    row = reading.slice(:read_at, :gallons, :water_inches, :temperature_f, :status)
                 .merge(feed_tank_id: id, sync_log_id: sync_log&.id, created_at: Time.current)
    # One INSERT … ON CONFLICT DO NOTHING: a reading already stored is left alone.
    inserted = TankReading.insert_all([row], unique_by: %i[feed_tank_id read_at]) # rubocop:disable Rails/SkipsModelValidations
    remember_latest(row[:read_at], row[:gallons], row[:status])
    inserted.rows.any? ? :created : :duplicate
  end

  private

  def remember_latest(read_at, gallons, status)
    return if last_read_at && last_read_at >= read_at

    update_columns(last_read_at: read_at, last_gallons: gallons, last_status: status, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
