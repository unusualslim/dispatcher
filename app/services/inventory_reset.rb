# STAGING ONLY. Takes costed inventory back to before opening balances: deletes every costed movement
# (with its FIFO layers and any inventory GL entries), zeroes stock at every location and clears the
# inventory start date. Sales orders, POs and production orders stay; InventoryReplay posts their
# movements again. Movements from before costing (no movement type) are kept as history.
#
# Then: import PDI's on-hand for the day before the start (report date on the import), set opening
# balances as of the start, replay, and import PDI's month-end report to compare.
module InventoryReset
  class NotAllowed < StandardError; end

  module_function

  def allowed?
    Rails.configuration.x.staging == true || Rails.env.local?
  end

  # Returns what was removed: { movements:, adjustments:, ledger_entries:, locations: }.
  def reset!
    raise NotAllowed, 'Inventory reset only runs on staging' unless allowed?

    ActiveRecord::Base.transaction do
      costed = InventoryTransaction.costed
      result = counts(costed).merge(ledger_entries: delete_ledger_entries!(costed))
      [InventoryLayerDraw.all, InventoryCostLayer.all, costed].each(&:delete_all)
      zero_stock!
      AppSetting.where(key: InventoryRevaluation::START_DATE_KEY).delete_all
      result
    end
  end

  def counts(costed)
    { movements: costed.count, adjustments: costed.where(movement_type: 'adjustment').count,
      locations: LocationProduct.where.not(quantity: 0).count }
  end

  # rubocop:disable Rails/SkipsModelValidations -- bulk reset of every stock row
  def zero_stock!
    Product.where(id: LocationProduct.select(:product_id)).update_all(current_stock: 0)
    LocationProduct.update_all(quantity: 0, inventory_value: 0, updated_at: Time.current)
  end

  # Inventory GL entries, and entries reversing them (production entries hang off production orders and stay).
  def delete_ledger_entries!(costed)
    ids = costed.where.not(ledger_entry_id: nil).distinct.pluck(:ledger_entry_id)
    ids += LedgerEntry.where(reversal_of_id: ids).pluck(:id)
    return 0 if ids.empty?

    InventoryTransaction.where(ledger_entry_id: ids).update_all(ledger_entry_id: nil, gl_posted_at: nil)
    LedgerLine.where(ledger_entry_id: ids).delete_all
    LedgerEntry.where(reversal_of_id: ids).delete_all
    LedgerEntry.where(id: ids).delete_all
    ids.size
  end
  # rubocop:enable Rails/SkipsModelValidations
end
