# A non-inventory cost (pallet, film, tape, label, labor, overhead) priced as bought: per each, roll,
# gallon, day... Product cost lines that use one take its unit cost, so updating it here re-costs every
# finished good on the next rollup. Labor lines still cost at the labor rate setting.
class CostItem < ApplicationRecord
  belongs_to :reporting_group
  has_many :product_cost_lines, dependent: :restrict_with_error

  UNITS = %w[each roll case pallet gallon day].freeze

  normalizes :name, :unit, :vendor, with: ->(value) { value.strip.presence }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }
  validate :non_inventory_group

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def label
    unit ? "#{name} (#{ActiveSupport::NumberHelper.number_to_currency(unit_cost, precision: 4)}/#{unit})" : name
  end

  private

  def non_inventory_group
    errors.add(:reporting_group, 'must be a non-inventory group') if reporting_group && !reporting_group.non_inventory?
  end
end
