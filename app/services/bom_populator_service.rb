class BomPopulatorService
  def initialize(production_order)
    @order = production_order
  end

  def call
    return false unless @order.product_id.present?

    bom_lines = ProductComponent.where(product_id: @order.product_id)
    return false if bom_lines.empty?

    bom_lines.each_with_index do |line, idx|
      qty_needed = line.quantity_per_unit * @order.qty_to_make
      @order.production_order_components.find_or_create_by(product_id: line.component_product_id) do |c|
        c.quantity    = qty_needed
        c.uom         = line.uom
        c.description = line.component_product&.name
        c.part_number = line.component_product&.id&.to_s
        c.position    = idx + 1
      end
    end
    true
  end
end
