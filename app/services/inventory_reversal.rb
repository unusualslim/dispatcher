# Undoes inventory transactions for a void: posts the opposite transaction at the same location
# and moves stock back. `source` is what's being voided (the new transactions point at it).
module InventoryReversal
  module_function

  def reverse!(transactions, source:, reference:, user:)
    transactions.includes(:product).find_each { |original| reverse_one!(original, source, reference, user) }
  end

  def reverse_one!(original, source, reference, user)
    InventoryTransaction.create!(
      product: original.product, quantity: original.quantity, direction: original.direction == 'in' ? 'out' : 'in',
      transactable: source, location_id: original.location_id, reference_number: reference,
      notes: "Void of #{reference}: reverses #{original.notes}".first(255), created_by_id: user&.id
    )
    adjust_stock!(original, original.direction == 'in' ? -original.quantity : original.quantity)
  end

  def adjust_stock!(original, delta)
    product = original.product
    return LocationProduct.adjust!(Location.find(original.location_id), product, delta) if original.location_id

    product.update!(current_stock: product.current_stock.to_d + delta)
  end
end
