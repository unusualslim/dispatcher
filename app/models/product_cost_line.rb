class ProductCostLine < ApplicationRecord
  # Lines in a labor reporting group are the only ones with actuals (/line crew-hours): their
  # unit cost is the labor rate setting and per_quantity is the standard units per worker-hour.
  belongs_to :product
  belongs_to :reporting_group

  validates :description, presence: true
  validates :quantity, :per_quantity, numericality: { greater_than: 0 }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }, unless: :labor?
  validate :non_inventory_group

  def labor?
    reporting_group&.labor?
  end

  def effective_unit_cost
    labor? ? AppSetting.labor_rate : unit_cost.to_d
  end

  def cost_per_unit
    quantity.to_d * effective_unit_cost / per_quantity.to_d
  end

  # Standard worker-hours per finished unit (labor lines only).
  def hours_per_unit
    labor? ? quantity.to_d / per_quantity.to_d : 0.to_d
  end

  private

  def non_inventory_group
    errors.add(:reporting_group, 'must be a non-inventory group') if reporting_group && !reporting_group.non_inventory?
  end
end
