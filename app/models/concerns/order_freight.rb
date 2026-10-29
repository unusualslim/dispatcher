# Freight on a customer order: the inputs the rules look at (origin, carrier, miles, extra stops, pump offs), the
# purchase and sale charges, and how the customer sees freight (its own line, or rolled into the product price).
module OrderFreight
  extend ActiveSupport::Concern

  PRESENTATIONS = { 'line' => 'Separate line item', 'in_price' => 'Rolled into the price' }.freeze

  included do
    belongs_to :freight_origin_location, class_name: 'Location', optional: true
    # Not a foreign key: PDI carrier IDs (pdi_carrier_id) aren't all vendors in the app.
    belongs_to :freight_carrier, class_name: 'Vendor', optional: true

    has_many :order_freight_charges, dependent: :destroy
    has_many :freight_payables, as: :source, dependent: :destroy

    validates :freight_presentation, inclusion: { in: PRESENTATIONS.keys }
    validates :freight_extra_stops, :freight_pump_offs,
              numericality: { greater_than_or_equal_to: 0, only_integer: true }
    after_save { @standard_miles = nil }
  end

  # Where the freight starts: set on the order, else the ship-from warehouse, the lines' PDI warehouse, or the
  # origin terminal of the order's dispatch.
  def freight_origin
    freight_origin_location || ship_from_location || customer_order_products.filter_map(&:location).first ||
      dispatch_origin_location
  end

  # The carrier hauling it: set on the order, else PDI's carrier on the order.
  def freight_carrier_vendor_id
    freight_carrier_id.presence || pdi_carrier_id.presence
  end

  def freight_carrier_vendor
    Vendor.find_by(id: freight_carrier_vendor_id) if freight_carrier_vendor_id
  end

  # Miles typed on the order, else the lane's standard miles, else a GPS estimate.
  def freight_miles_or_estimate = freight_miles || standard_miles.first

  # :order, :lane, :gps or nil.
  def freight_miles_source
    freight_miles ? :order : standard_miles.last
  end

  def freight_miles_estimated? = freight_miles_source == :gps

  def freight_purchase_total = order_freight_charges.select { |c| c.side == 'purchase' }.sum(0.to_d, &:amount)
  def freight_sale_total = order_freight_charges.select { |c| c.side == 'sale' }.sum(0.to_d, &:amount)
  def freight_margin = freight_sale_total - freight_purchase_total
  def freight_in_price? = freight_presentation == 'in_price'

  # Freight PDI already put on the order as product lines ("Freight - DEF"): PDI bills those, so calculated sale
  # freight is shown beside them for comparison rather than added to the total.
  def billed_freight_lines
    customer_order_products.select { |line| (line.product&.name || line.product_name).to_s.match?(/freight/i) }
  end

  def billed_freight_total = billed_freight_lines.sum { |l| l.quantity.to_d * l.price.to_d }

  # Sale freight per unit when it's rolled into the price, spread over every unit on the order.
  def freight_per_unit
    units = (customer_order_products.to_a - billed_freight_lines).sum { |line| line.quantity.to_d }
    units.positive? ? freight_sale_total / units : 0.to_d
  end

  # The price the customer sees: the product price, plus its share of freight when freight is rolled in.
  def delivered_price(line)
    return line.price unless freight_in_price? && line.price

    line.price.to_d + freight_per_unit
  end

  private

  def dispatch_origin_location = dispatches.filter_map(&:origin_location).first

  def standard_miles
    @standard_miles ||= Freight::Miles.between(freight_origin, location)
  end
end
