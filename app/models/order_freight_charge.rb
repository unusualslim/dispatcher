# A freight charge on a customer order: what we pay the carrier (purchase) or charge the customer (sale).
# Calculated charges come from freight rules and are replaced on every recalculation; manual ones (warehouse
# goods, one-off quotes) stay until removed.
class OrderFreightCharge < ApplicationRecord
  SIDES = FreightRule::SIDES.keys.freeze

  belongs_to :customer_order
  belongs_to :freight_rule, optional: true
  belongs_to :freight_class, optional: true
  belongs_to :carrier, class_name: 'Vendor', optional: true

  normalizes :carrier_id, with: ->(value) { value.presence }

  validates :side, inclusion: { in: SIDES }
  validates :charge_type, inclusion: { in: FreightRule::CHARGE_TYPES.keys }
  validates :amount, numericality: true

  scope :purchase, -> { where(side: 'purchase') }
  scope :sale, -> { where(side: 'sale') }
  scope :ordered, -> { order(:side, :calculated, :id) }

  def charge_label = FreightRule::CHARGE_TYPES[charge_type]
  def basis_label = FreightRule::BASES[basis]

  # A sale priced as cost + markup %.
  def mark_up(cost, percent)
    assign_attributes(basis: 'markup', quantity: cost, rate: percent, amount: (cost * (1 + (percent / 100))).round(2))
  end

  def label
    description.presence || [charge_label, freight_class && "Class #{freight_class.code}"].compact.join(' – ')
  end
end
