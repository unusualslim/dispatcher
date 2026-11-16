# Turns a monitor's feed tank (Kii sensor, Smartank tank) into an app tank at a location, from the monitor's own
# profile: its name and capacity, and its product ID (Kii Parameter_2 / Smartank User Product ID; else a guess from
# the product text). The monitor's profile wins over the tank settings copied from location products: when the
# location already has a tank of that product that no monitor feeds, the monitor takes it over (capacity from the
# monitor, the copied fill and bottom percentages kept) instead of adding a second tank.
#
# Imports call #auto_link! so a feed tank whose monitor carries the app location number (Kii Parameter_1 /
# Smartank User Defined A) links itself; the rest are set up by hand on Tank Feeds (#apply!).
class TankSetup
  MONITOR_FEEDS = %w[kii smartank].freeze
  # Product text that is clearly DEF, for monitors whose product ID isn't filled in yet.
  DEF_GUESS = /\bDEF\b|diesel exhaust/i
  DEF_PRODUCT_ID = '901'.freeze

  attr_reader :feed_tank

  def initialize(feed_tank)
    @feed_tank = feed_tank
  end

  delegate :details, to: :feed_tank

  # The location the monitor names (its app location number), if it exists.
  def monitor_location
    id = details['location_id'].to_s.strip
    Location.find_by(id: id) if id.match?(/\A\d+\z/)
  end

  # The monitor's product ID if it's a real product, else a guess from its product text.
  def suggested_product_id
    id = details['product_id'].to_s.strip
    return id if id.present? && Product.exists?(id: id)

    DEF_PRODUCT_ID if [details['product'], details['content'], feed_tank.name].compact.join(' ').match?(DEF_GUESS)
  end

  def capacity
    details['capacity'].to_s.delete(',').to_d.nonzero?
  end

  # Links on import when the monitor names a location. Returns the tank, or nil when it can't.
  def auto_link!
    return if feed_tank.tank_id || feed_tank.ignored || MONITOR_FEEDS.exclude?(feed_tank.feed)

    location = monitor_location
    apply!(location: location, product_id: suggested_product_id) if location
  end

  # Creates (or takes over) the tank at the location and links the feed tank to it.
  def apply!(location:, product_id:)
    Tank.transaction do
      tank = takeover_tank(location, product_id) || new_tank(location, product_id)
      tank.save!
      feed_tank.update!(tank: tank, ignored: false)
      tank
    end
  end

  private

  def new_tank(location, product_id)
    Tank.new(location: location, product_id: product_id.presence, capacity_gallons: capacity, ownership: 'managed',
             name: feed_tank.name.presence || feed_tank.external_id)
  end

  # A tank at the location with the same product that no monitor feeds yet (copied from location products, or
  # entered by hand): the monitor's capacity replaces its own, keeping its fill and bottom percentages.
  def takeover_tank(location, product_id)
    return if product_id.blank?

    tank = location.tanks.active.where(product_id: product_id).detect { |t| unmonitored?(t) }
    return unless tank

    rescale(tank)
    tank.name = feed_tank.name if feed_tank.name.present?
    tank
  end

  def unmonitored?(tank)
    tank.feed_tanks.none? { |f| f.feed.in?(MONITOR_FEEDS) }
  end

  # Monitor capacity; fill limit and bottom keep their shares (blank ones fall back to the tank defaults).
  def rescale(tank)
    return unless capacity

    fill_share = share(tank.fill_limit_gallons, tank.capacity_gallons)
    bottom_share = share(tank.bottom_gallons, tank.fill_limit_gallons)
    fill = fill_share && (capacity * fill_share).round
    tank.assign_attributes(capacity_gallons: capacity, fill_limit_gallons: fill,
                           bottom_gallons: bottom_share && fill && (fill * bottom_share).round)
  end

  def share(part, whole)
    part / whole if part && whole.to_d.positive?
  end
end
