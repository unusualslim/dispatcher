# Standard cost rollups: BOM materials plus non-inventory cost lines.
module ProductCosting
  extend ActiveSupport::Concern

  # Most recent standard cost in effect on the given date (ignores future-dated entries).
  # Falls back to the standard_cost column for products with no history rows.
  def current_standard_cost(date = Date.today)
    history = standard_cost_histories.find { |h| h.effective_date <= date }
    history ? history.amount : standard_cost
  end

  # Full standard cost: inventory materials + non-inventory cost lines.
  # Returns nil if there is no BOM or any component is missing a standard cost,
  # so a price is never quoted off a partial cost.
  def bom_standard_cost(date = Date.today)
    (material = material_standard_cost(date)) && (material + non_inventory_standard_cost)
  end

  # Sum of each BOM component's standard cost × quantity per unit (nil when incomplete).
  def material_standard_cost(date = Date.today)
    return nil if product_components.empty?
    return nil if bom_components_missing_standard_cost(date).any?

    product_components.sum do |pc|
      pc.component_product.current_standard_cost(date).to_d * pc.quantity_per_unit.to_d
    end
  end

  # Per-unit cost of pallets, supplies, labor and overhead (what PDI's repack fee covers).
  def non_inventory_standard_cost
    product_cost_lines.sum(0.to_d, &:cost_per_unit)
  end

  # BOM component products with no standard cost in effect on the given date.
  def bom_components_missing_standard_cost(date = Date.today)
    product_components.filter_map do |pc|
      component = pc.component_product
      component if component && component.current_standard_cost(date).nil?
    end
  end
end
