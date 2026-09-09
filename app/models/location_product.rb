class LocationProduct < ApplicationRecord
  belongs_to :location
  belongs_to :product

  # Adjust per-location stock by delta (positive = in, negative = out).
  # Creates the location_product row if it doesn't exist.
  # Also keeps Product.current_stock in sync as a global total.
  def self.adjust!(location, product, delta)
    lp = find_or_initialize_by(location_id: location.id, product_id: product.id)
    lp.quantity = (lp.quantity || 0) + delta
    lp.save!
    product.update_column(:current_stock, where(product_id: product.id).sum(:quantity))
  end
end
