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

  def post!(order, user = nil)
    return if posted?(order)

    consume_components!(order, user)
    finished = order.product
    produced = order.total_qty_produced.to_d
    move!(order, finished, produced, 'in', user) if finished && !finished.is_raw_material? && produced.positive?
  end

  def reverse!(order, user = nil)
    InventoryReversal.reverse!(moves(order), source: order, reference: order.number, user: user)
  end

  # Actual quantities when entered, otherwise the planned quantity scaled to what was produced.
  def consume_components!(order, user)
    ratio = produced_ratio(order)
    order.production_order_components.includes(:product).find_each do |comp|
      used = comp.quantity_actual.presence&.to_d || (comp.quantity.to_d * ratio)
      move!(order, comp.product, used, 'out', user) if comp.product && used.positive?
    end
  end

  def produced_ratio(order)
    planned = order.qty_to_make.to_d
    planned.positive? ? order.total_qty_produced.to_d / planned : 1
  end

  def move!(order, product, qty, direction, user)
    InventoryTransaction.create!(product: product, quantity: qty, direction: direction, transactable: order,
                                 reference_number: order.number, created_by_id: user&.id,
                                 location_id: order.location_id,
                                 notes: "#{direction == 'in' ? 'Produced' : 'Consumed'} in #{order.number}")
    delta = direction == 'in' ? qty : -qty
    return LocationProduct.adjust!(order.location, product, delta) if order.location

    product.update!(current_stock: product.current_stock.to_d + delta)
  end
end
