class ReorderService
  def self.run
    new.run
  end

  def run
    created = []
    Product.below_reorder_point.each do |product|
      # Skip if there's already a non-cancelled PO in flight for this product
      next if PurchaseOrder.active.exists?(product: product)

      vendor       = preferred_vendor_for(product)
      qty_to_order = calculate_order_quantity(product)

      po = PurchaseOrder.create!(
        product:        product,
        vendor:         vendor,
        quantity:       qty_to_order,
        unit_cost:      product.cost_per_unit,
        status:         'draft',
        trigger_type:   'auto_reorder',
        trigger_reason: "Stock (#{product.current_stock} #{product.unit_of_measurement}) " \
                        "at or below reorder point (#{product.reorder_point} #{product.unit_of_measurement})"
      )
      created << po
    end
    created
  end

  private

  def preferred_vendor_for(product)
    PurchaseOrder.where(product: product).order(created_at: :desc).first&.vendor ||
      Vendor.first
  end

  def calculate_order_quantity(product)
    target = (product.reorder_point || 0) + (product.safety_stock || 0)
    [target - (product.current_stock || 0), 1].max.ceil
  end
end
