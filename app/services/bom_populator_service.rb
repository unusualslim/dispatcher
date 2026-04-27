class BomPopulatorService
  def initialize(production_order)
    @order = production_order
  end

  def call
    return false unless @order.product_id.present?

    bom_lines = ProductComponent.where(product_id: @order.product_id)
    return false if bom_lines.empty?

    bom_lines.each_with_index do |line, idx|
      qty_needed = line.quantity_per_unit.to_d * @order.qty_to_make.to_d
      comp = @order.production_order_components.find_or_initialize_by(product_id: line.component_product_id)
      comp.quantity    = qty_needed
      comp.uom         = line.uom
      comp.description = line.component_product&.name
      comp.part_number = line.component_product&.id&.to_s
      comp.position    = idx + 1
      comp.save!
    end
    true
  end
end
