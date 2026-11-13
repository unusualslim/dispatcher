# A tank at a location: a customer tank we keep filled ("managed") or one whose product is our inventory ("ours").
# Its level comes from the feed tanks mapped to it (FeedTank); several feed tanks can add up to one tank, as at
# site 0002, where the Power Automate email lists each production and holding tank.
class Tank < ApplicationRecord
  OWNERSHIPS = { 'managed' => 'Managed (customer)', 'ours' => 'Ours (FPS inventory)' }.freeze
  DEFAULT_FILL_LIMIT = 0.9 # share of capacity a delivery may fill to
  DEFAULT_BOTTOM = 0.1     # share of the fill limit treated as empty (the spreadsheet's 10%)

  belongs_to :location
  belongs_to :product, optional: true
  has_many :feed_tanks, dependent: :nullify

  validates :name, presence: true
  validates :ownership, inclusion: { in: OWNERSHIPS.keys }
  validates :capacity_gallons, :fill_limit_gallons, :bottom_gallons,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :limits_fit_capacity

  before_validation :default_limits

  scope :active, -> { where(active: true) }
  scope :ordered, -> { joins(:location).order('locations.company_name', :name) }

  def label
    "#{location&.company_name} – #{name}"
  end

  # The feed tanks that make up its level (ignored ones never count).
  def sources
    feed_tanks.reject(&:ignored)
  end

  # Latest level: the sum of each source's last reading.
  def current_gallons
    readings = sources.filter_map(&:last_gallons)
    readings.sum if readings.any?
  end

  # When the level was last known: the oldest of its sources' last readings.
  def last_read_at
    sources.filter_map(&:last_read_at).min
  end

  def stale?(now = Time.current)
    last_read_at.nil? || last_read_at < now - FeedTank.stale_hours.hours
  end

  # A level the site phoned in: stored on the tank's own "manual" feed tank.
  def record_manual_reading!(gallons, read_at:, by:)
    manual = FeedTank.find_or_create_by!(feed: 'manual', external_id: "tank-#{id}") do |feed_tank|
      feed_tank.tank = self
      feed_tank.name = "Manual (#{name})"
    end
    manual.record_reading!({ read_at: read_at, gallons: gallons, status: "by #{by.email}" })
  end

  # Room up to the fill limit.
  def safe_ullage
    return unless fill_limit_gallons && current_gallons

    fill_limit_gallons - current_gallons
  end

  private

  def default_limits
    return if capacity_gallons.blank?

    self.fill_limit_gallons ||= (capacity_gallons * DEFAULT_FILL_LIMIT).round
    self.bottom_gallons ||= (fill_limit_gallons * DEFAULT_BOTTOM).round
  end

  def limits_fit_capacity
    return unless capacity_gallons && fill_limit_gallons

    errors.add(:fill_limit_gallons, 'is more than the capacity') if fill_limit_gallons > capacity_gallons
    errors.add(:bottom_gallons, 'is above the fill limit') if bottom_gallons && bottom_gallons >= fill_limit_gallons
  end
end
