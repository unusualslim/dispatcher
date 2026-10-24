# Voids a purchase order: reverses anything it posted to inventory and marks it voided
# (read-only from then on). A PO already sent to PDI has to be voided in PDI as well.
class PurchaseOrderVoid
  def initialize(purchase_order, user, reason)
    @po = purchase_order
    @user = user
    @reason = reason.to_s.strip
  end

  def call!
    raise ArgumentError, 'Already voided' if @po.voided?
    raise ArgumentError, 'Give a reason for voiding' if @reason.blank?

    @po.with_lock do
      receipts = @po.inventory_transactions.where(direction: 'in') # InventoryReversal skips any already reversed
      InventoryReversal.reverse!(receipts, source: @po, reference: @po.pdi_reference || @po.id.to_s, user: @user)
      @po.update!(status: 'voided', voided_at: Time.current, voided_by: @user, void_reason: @reason)
    end
  end
end
