class ReorderService
  def self.run
    new.run
  end

  def run
    created = []
    Product.below_reorder_point.each do |product|
      # Skip if there's already a non-cancelled PO in flight for this product
      next if PurchaseOrder.active.joins(:line_items)
                           .where(purchase_order_line_items: { product_id: product.id })
                           .exists?

      vendor       = preferred_vendor_for(product)
      qty_to_order = calculate_order_quantity(product)

      po = PurchaseOrder.create!(
        vendor:         vendor,
        status:         'draft',
        trigger_type:   'auto_reorder',
        trigger_reason: "Stock (#{product.current_stock} #{product.unit_of_measurement}) " \
                        "at or below reorder point (#{product.reorder_point} #{product.unit_of_measurement})"
      )
      po.line_items.create!(
        product:   product,
        quantity:  qty_to_order,
        unit_cost: product.cost_per_unit
      )
      created << po
    end
    created
  end

  private

  def preferred_vendor_for(product)
    last_po = PurchaseOrder.joins(:line_items)
                           .where(purchase_order_line_items: { product_id: product.id })
                           .order(created_at: :desc)
                           .first
    last_po&.vendor || Vendor.first
  end

  def calculate_order_quantity(product)
    target = (product.reorder_point || 0) + (product.safety_stock || 0)
    [target - (product.current_stock || 0), 1].max.ceil
  end
end
