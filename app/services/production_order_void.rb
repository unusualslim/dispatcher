# Voids a production order: undoes the inventory its completed batches moved, reverses its posted
# GL entry, clocks out any crew still on it, and marks it voided (read-only from then on).
class ProductionOrderVoid
  def initialize(order, user, reason)
    @order = order
    @user = user
    @reason = reason.to_s.strip
  end

  def call!
    raise ArgumentError, 'Already voided' if @order.voided?
    raise ArgumentError, 'Give a reason for voiding' if @reason.blank?

    @order.with_lock do
      reverse_inventory!
      LedgerEntry.active_for(@order)&.reverse!(@user)
      @order.jobs.active.find_each(&:clock_out!)
      @order.update!(status: 'voided', voided_at: Time.current, voided_by: @user, void_reason: @reason)
    end
  end

  private

  def reverse_inventory!
    batch_ids = @order.production_order_batches.ids
    InventoryTransaction.where(transactable_type: 'ProductionOrderBatch', transactable_id: batch_ids)
                        .includes(:product).find_each { |tx| reverse!(tx) }
  end

  def reverse!(original)
    InventoryTransaction.create!(
      product: original.product, quantity: original.quantity, direction: original.direction == 'in' ? 'out' : 'in',
      transactable: @order, location_id: original.location_id, reference_number: @order.number,
      notes: "Void of #{@order.number}: reverses #{original.notes}".first(255), created_by_id: @user&.id
    )
    adjust_stock!(original, original.direction == 'in' ? -original.quantity : original.quantity)
  end

  def adjust_stock!(original, delta)
    product = original.product
    return LocationProduct.adjust!(Location.find(original.location_id), product, delta) if original.location_id

    product.update!(current_stock: product.current_stock.to_d + delta)
  end
end
