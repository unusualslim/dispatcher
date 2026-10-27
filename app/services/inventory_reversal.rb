# Undoes inventory transactions (voids, reopened production orders): posts the opposite transaction
# at the same location and cost, linked to the original so nothing is reversed twice, and moves stock back.
# `source` is what's being voided or reopened (the new transactions point at it).
module InventoryReversal
  module_function

  def reverse!(transactions, source:, reference:, user:)
    transactions.in_effect.includes(:product).find_each do |original|
      next InventoryPosting.reverse!(original, source: source, reference: reference, user: user) if original.location_id

      reverse_one!(original, source, reference, user)
    end
  end

  # Older moves with no location only changed products.current_stock.
  def reverse_one!(original, source, reference, user)
    InventoryTransaction.create!(
      product: original.product, quantity: original.quantity, direction: original.direction == 'in' ? 'out' : 'in',
      transactable: source, reversal_of: original, location_id: original.location_id, reference_number: reference,
      notes: "Void of #{reference}: reverses #{original.notes}".first(255), created_by_id: user&.id
    )
    adjust_stock!(original, original.direction == 'in' ? -original.quantity : original.quantity)
  end

  def adjust_stock!(original, delta)
    product = original.product
    product.update!(current_stock: product.current_stock.to_d + delta)
  end
end
