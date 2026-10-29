# Says which freight table to use, and what its rate means, when an order matches: this side (what we pay the
# carrier, or what we charge the customer), charge type, origin, freight class, carrier and customer on this date.
# Blank selectors match anything; the most specific matching rule wins (FreightRule.best).
class FreightRule < ApplicationRecord
  SIDES = { 'purchase' => 'Purchase (carrier cost)', 'sale' => 'Sale (charge customer)' }.freeze
  CHARGE_TYPES = { 'freight' => 'Freight', 'fuel_surcharge' => 'Fuel surcharge', 'extra_stop' => 'Additional stop',
                   'pump_off' => 'Pump off' }.freeze
  BASES = { 'per_unit' => 'Per gallon / unit', 'per_load' => 'Per load', 'per_stop' => 'Per additional stop',
            'per_pump_off' => 'Per pump off', 'percent' => 'Percent of freight', 'flat' => 'Flat per order',
            'markup' => 'Purchase cost + markup' }.freeze
  # Each charge type's usual basis, for the form.
  DEFAULT_BASIS = { 'freight' => 'per_unit', 'fuel_surcharge' => 'percent', 'extra_stop' => 'per_stop',
                    'pump_off' => 'per_pump_off' }.freeze

  belongs_to :freight_table, optional: true
  belongs_to :origin_location, class_name: 'Location', optional: true
  belongs_to :freight_class, optional: true
  belongs_to :carrier, class_name: 'Vendor', optional: true
  belongs_to :customer, optional: true
  has_many :order_freight_charges, dependent: :nullify

  normalizes :name, with: ->(value) { value.strip.presence }
  normalizes :carrier_id, with: ->(value) { value.presence }

  validates :name, :effective_from, presence: true
  validates :side, inclusion: { in: SIDES.keys }
  validates :charge_type, inclusion: { in: CHARGE_TYPES.keys }
  validates :basis, inclusion: { in: BASES.keys }
  validates :freight_table, presence: true, unless: :markup?
  validates :markup_percent, numericality: true, if: :markup?
  validate :markup_only_on_sales
  validate :dates_in_order

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:side, :charge_type, :name) }
  scope :effective_on, lambda { |date|
    where(effective_from: ..date).where('freight_rules.effective_to IS NULL OR freight_rules.effective_to >= ?', date)
  }

  # The most specific active rule for the situation, or nil. A rule naming the customer beats one naming the
  # carrier, which beats origin, which beats class; ties go to the latest effective date.
  # Selectors: origin_id, freight_class_id, carrier_id, customer_id (nil = the order has none).
  def self.best(side:, charge_type:, date:, **selectors)
    candidates = active.effective_on(date).where(side: side, charge_type: charge_type)
                       .where(origin_location_id: [nil, selectors[:origin_id]],
                              freight_class_id: [nil, selectors[:freight_class_id]],
                              carrier_id: [nil, selectors[:carrier_id].presence],
                              customer_id: [nil, selectors[:customer_id]])
                       .includes(freight_table: :rates)
    candidates.max_by { |rule| [rule.specificity, rule.effective_from, rule.id] }
  end

  def specificity
    (customer_id ? 8 : 0) + (carrier_id ? 4 : 0) + (origin_location_id ? 2 : 0) + (freight_class_id ? 1 : 0)
  end

  def markup? = basis == 'markup'
  def side_label = SIDES[side]&.split(' (')&.first
  def charge_label = CHARGE_TYPES[charge_type]
  def basis_label = BASES[basis]

  # "Origin: Bainbridge · Class A · Carrier: KML" — what the rule is limited to.
  def selector_summary
    parts = [customer && "Customer: #{customer.name}", carrier && "Carrier: #{carrier.name}",
             origin_location && "Origin: #{origin_location.company_name}",
             freight_class && "Class #{freight_class.code}"]
    parts.compact.join(' · ').presence || 'Any order'
  end

  private

  def markup_only_on_sales
    errors.add(:basis, 'markup only applies to sale rules') if markup? && side != 'sale'
  end

  def dates_in_order
    errors.add(:effective_to, 'must be on or after the effective date') if effective_to && effective_from &&
                                                                           effective_to < effective_from
  end
end
