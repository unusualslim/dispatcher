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
      ProductionOrderInventory.reverse!(@order, @user)
      LedgerEntry.active_for(@order)&.reverse!(@user)
      @order.jobs.active.find_each(&:clock_out!)
      @order.update!(status: 'voided', voided_at: Time.current, voided_by: @user, void_reason: @reason)
    end
  end
end
