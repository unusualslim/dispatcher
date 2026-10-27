class ProductCostLine < ApplicationRecord
  # Lines in a labor reporting group are the only ones with actuals (/line crew-hours): their
  # unit cost is the labor rate setting and per_quantity is the standard units per worker-hour.
  # Lines picked from the cost item catalog take the item's current unit cost.
  belongs_to :product
  belongs_to :reporting_group
  belongs_to :cost_item, optional: true

  # Empty rows on the product form (no description and no cost item) are skipped.
  BLANK_ROW = ->(attrs) { attrs['description'].blank? && attrs['cost_item_id'].blank? }

  before_validation :fill_from_cost_item

  validates :description, presence: true
  validates :quantity, :per_quantity, numericality: { greater_than: 0 }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }, unless: -> { labor? || cost_item }
  validate :non_inventory_group

  def labor?
    reporting_group&.labor?
  end

  def effective_unit_cost
    return AppSetting.labor_rate if labor?

    cost_item ? cost_item.unit_cost.to_d : unit_cost.to_d
  end

  def cost_per_unit
    quantity.to_d * effective_unit_cost / per_quantity.to_d
  end

  # Standard worker-hours per finished unit (labor lines only).
  def hours_per_unit
    labor? ? quantity.to_d / per_quantity.to_d : 0.to_d
  end

  private

  def fill_from_cost_item
    return unless cost_item

    self.reporting_group = cost_item.reporting_group
    self.description = cost_item.name if description.blank?
  end

  def non_inventory_group
    errors.add(:reporting_group, 'must be a non-inventory group') if reporting_group && !reporting_group.non_inventory?
  end
end
