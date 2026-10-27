# Inventory for a production order (the order is the batch): completing it consumes the components
# and adds the finished goods; reopening or voiding reverses whatever is still in effect.
# Older orders moved inventory per PDI batch, so those batch moves count too.
module ProductionOrderInventory
  module_function

  def moves(order)
    InventoryTransaction.where(transactable: order)
                        .or(InventoryTransaction.where(transactable_type: 'ProductionOrderBatch',
                                                       transactable_id: order.production_order_batches.select(:id)))
  end

  def posted?(order)
    moves(order).in_effect.exists?
  end

  # Finished goods come in at what went into them: the components' inventory cost plus the absorbed
  # supplies, overhead and labor (ProductionOrderCosting). Standard products book at standard instead.
  def post!(order, user = nil)
    return if posted?(order)

    consumed = consume_components!(order, user)
    finished = order.product
    produced = order.total_qty_produced.to_d
    return unless finished && !finished.is_raw_material? && produced.positive?

    unit_cost = (consumed + ProductionOrderCosting.new(order).absorbed_cost) / produced
    move!(order, finished, produced, user, unit_cost: unit_cost)
  end

  def reverse!(order, user = nil)
    InventoryReversal.reverse!(moves(order), source: order, reference: order.number, user: user)
  end

  # Actual quantities when entered, otherwise the planned quantity scaled to what was produced.
  # Returns the inventory cost of what was used.
  def consume_components!(order, user)
    ratio = produced_ratio(order)
    order.production_order_components.includes(:product).find_each.sum(0.to_d) do |comp|
      used = used_quantity(comp, ratio)
      comp.product && used.positive? ? move!(order, comp.product, -used, user).total_cost : 0
    end
  end

  def used_quantity(comp, ratio)
    comp.quantity_actual.presence&.to_d || (comp.quantity.to_d * ratio)
  end

  def produced_ratio(order)
    planned = order.qty_to_make.to_d
    planned.positive? ? order.total_qty_produced.to_d / planned : 1
  end

  # qty signed: produced goods in, components out.
  def move!(order, product, qty, user, unit_cost: nil)
    InventoryPosting.post!(product: product, location: order.location, quantity: qty,
                           movement_type: qty.positive? ? 'production_output' : 'production_use',
                           unit_cost: unit_cost, source: order, reference: order.number, user: user,
                           notes: "#{qty.positive? ? 'Produced' : 'Consumed'} in #{order.number}")
  end
end
