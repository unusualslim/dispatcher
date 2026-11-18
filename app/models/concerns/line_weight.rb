# Total shipping weight of an order's or PO's lines: product weight (lb per unit) × quantity. Lines whose product has
# no weight are counted in #unweighed_lines, so a partial total says so.
module LineWeight
  extend ActiveSupport::Concern

  def total_weight_lbs
    weighed = weight_lines.select { |line| line.product&.weight }
    weighed.sum(0.to_d) { |line| line.quantity.to_d * line.product.weight.to_d } if weighed.any?
  end

  def unweighed_lines
    weight_lines.count { |line| line.product_id.present? && line.product&.weight.nil? }
  end
end
