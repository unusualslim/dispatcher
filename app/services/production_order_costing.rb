# Standard vs actual cost of a production order (the production order is the batch).
#
# PDI's repack capitalizes pdi_repack_fee × qty into a clearing account. The app absorbs
# that against supplies and overhead at standard plus line labor at actual (/line
# crew-hours × the labor rate); whatever is left over is the variance.
#
# Uses the product's current cost lines and rates, so figures move if the BOM changes.
class ProductionOrderCosting
  Line = Struct.new(:description, :reporting_group, :cost_per_unit, :standard, keyword_init: true)

  attr_reader :production_order, :product

  def initialize(production_order)
    @production_order = production_order
    @product = production_order.product
  end

  def qty_produced
    @qty_produced ||= if production_order.total_qty_produced.present?
                        production_order.total_qty_produced.to_d
                      else
                        production_order.production_order_batches.sum { |b| b.quantity.to_d }
                      end
  end

  def labor_rate
    @labor_rate ||= AppSetting.labor_rate
  end

  def material_standard
    unit = product&.material_standard_cost
    unit && (unit * qty_produced)
  end

  def lines
    @lines ||= (product&.product_cost_lines&.includes(:reporting_group, :cost_item) || []).map do |cl|
      Line.new(description: cl.description, reporting_group: cl.reporting_group, cost_per_unit: cl.cost_per_unit,
               standard: cl.cost_per_unit * qty_produced)
    end
  end

  def non_labor_lines
    lines.reject { |l| l.reporting_group.labor? }
  end

  # Where actual labor posts: the product's labor line group, else the first labor group.
  def labor_group
    @labor_group ||= lines.map(&:reporting_group).find(&:labor?) ||
                     ReportingGroup.non_inventory.ordered.find_by(labor: true)
  end

  def standard_labor_hours_per_unit
    product ? product.product_cost_lines.sum(0.to_d, &:hours_per_unit) : 0.to_d
  end

  def standard_labor_hours
    standard_labor_hours_per_unit * qty_produced
  end

  # Actual /line hours by worker employment type, e.g. { 'full_time' => 18.5, 'temp' => 6.5 };
  # each type credits its own wage account.
  def actual_labor_hours_by_type
    @actual_labor_hours_by_type ||= production_order.jobs.flat_map(&:job_workers)
                                                    .group_by { |jw| jw.user.employment_type }
                                                    .transform_values { |jws| hours(jws) }
  end

  def actual_labor_hours
    actual_labor_hours_by_type.values.sum(0.to_d)
  end

  def standard_labor_cost
    lines.select { |l| l.reporting_group.labor? }.sum(0.to_d, &:standard)
  end

  def actual_labor_cost
    actual_labor_hours * labor_rate
  end

  # Earned standard hours ÷ actual hours; nil until both exist.
  def labor_efficiency
    return nil if actual_labor_hours.zero? || standard_labor_hours.zero?

    standard_labor_hours / actual_labor_hours
  end

  def non_inventory_standard
    lines.sum(0.to_d, &:standard)
  end

  # What gets credited out of repack clearing: supplies/overhead at standard + actual labor.
  def absorbed_cost
    non_labor_lines.sum(0.to_d, &:standard) + actual_labor_cost
  end

  def repack_fee_applied
    product&.pdi_repack_fee && (product.pdi_repack_fee.to_d * qty_produced)
  end

  # Positive = PDI capitalized more than the absorbed cost (favorable).
  # nil until there's a fee and a quantity produced (with no quantity, all labor would look like variance).
  def variance
    return nil unless repack_fee_applied && qty_produced.positive?

    repack_fee_applied - absorbed_cost
  end

  def actual_cost_per_unit
    return nil if qty_produced.zero?

    absorbed_cost / qty_produced
  end

  private

  def hours(job_workers)
    job_workers.sum { |jw| jw.duration_seconds.to_d } / 3600
  end
end
