# Copies the tank settings kept on location products (max capacity, fill "uleage" %, cutoff %; one tank per product
# per site) into Tanks, for the sites no monitor covers yet. A monitor set up later takes the copied tank over
# (TankSetup). Run from Dispatch → Tanks with a preview; running it again skips what's already there.
#
# Lance's calls (charter T18, T20, 16 Nov 2026): the fuel tank rows are skipped (they leave with the fuel company),
# the obsolete FPS001 rows become 901, and the customer that renumbered its site has location 70's tank on 527
# (70 stays as an archive).
class TankCopy
  SKIP_PRODUCTS = %w[FPS011 FPS012].freeze # dyed ULSD and non-ethanol gas at Perry Brothers main
  PRODUCT_MOVES = { 'FPS001' => '901' }.freeze
  LOCATION_MOVES = { 70 => 527 }.freeze

  Plan = Struct.new(:row, :location_id, :product_id, :capacity, :fill_limit, :bottom, :skip, keyword_init: true) do
    def create? = skip.nil?
  end

  def plans
    @plans ||= begin
      seen = Set.new
      rows.map { |row| plan(row, seen) }
    end
  end

  def to_create
    plans.select(&:create?)
  end

  def run!
    Tank.transaction do
      to_create.map do |p|
        Tank.create!(location_id: p.location_id, product_id: p.product_id, name: tank_name(p), ownership: 'managed',
                     capacity_gallons: p.capacity, fill_limit_gallons: p.fill_limit, bottom_gallons: p.bottom,
                     notes: 'Copied from the location product tank settings.')
      end
    end
  end

  def locations
    ids = rows.map { |r| LOCATION_MOVES.fetch(r.location_id, r.location_id) }
    @locations ||= Location.where(id: ids).index_by(&:id)
  end

  def products
    @products ||= Product.where(id: rows.map { |r| PRODUCT_MOVES.fetch(r.product_id, r.product_id) }).index_by(&:id)
  end

  private

  def rows
    @rows ||= LocationProduct.where('max_capacity > 0').order(:location_id, :product_id).to_a
  end

  def plan(row, seen)
    location_id = LOCATION_MOVES.fetch(row.location_id, row.location_id)
    product_id = PRODUCT_MOVES.fetch(row.product_id, row.product_id)
    capacity = row.max_capacity.to_d
    fill = percent_of(capacity, row.uleage_90)
    bottom = fill && percent_of(fill, row.cutoff)
    Plan.new(row: row, location_id: location_id, product_id: product_id, capacity: capacity, fill_limit: fill,
             bottom: bottom, skip: skip_reason(row, location_id, product_id, seen))
  end

  # nil percent → nil (the tank's default: 90% fill, bottom 10% of the fill limit)
  def percent_of(amount, percent)
    (amount * percent.to_d / 100).round if percent.to_d.positive? && percent.to_d < 100
  end

  def skip_reason(row, location_id, product_id, seen)
    return 'Fuel tank (leaves with the fuel company)' if SKIP_PRODUCTS.include?(row.product_id)
    return "Location #{location_id} not found" unless locations[location_id]
    return "Product #{product_id} not found" unless products[product_id]
    return 'Location already has a tank of this product' if existing.include?([location_id, product_id])
    return 'Same site and product as a row above' unless seen.add?([location_id, product_id])

    nil
  end

  def existing
    @existing ||= Tank.where(location_id: locations.keys).pluck(:location_id, :product_id).to_set
  end

  def tank_name(plan)
    products[plan.product_id]&.name.presence || plan.product_id
  end
end
