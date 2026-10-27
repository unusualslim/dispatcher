# Value-only inventory postings: opening balances, a standard cost change, or a reporting group switching
# costing method. Quantities never change here.
module InventoryRevaluation
  START_DATE_KEY = 'inventory_tracking_start_date'.freeze

  module_function

  # The day costed tracking began (opening balances); sales before it are already in PDI's numbers.
  def start_date
    AppSetting.get(START_DATE_KEY)&.to_date
  end

  def started?
    start_date.present?
  end

  # Values every location's stock at the product's basis: standard for standard groups, otherwise PDI's
  # weighted average (cost_per_unit). FIFO stock starts as one layer at that cost. Runs once.
  def opening!(user: nil, as_of: Date.current)
    raise ArgumentError, "Opening balances were already set on #{start_date}" if started?

    ActiveRecord::Base.transaction do
      tracked_stock.find_each { |stock| open_stock!(stock, as_of, user) }
      AppSetting.set(START_DATE_KEY, as_of.iso8601)
    end
  end

  def open_stock!(stock, as_of, user)
    unit = opening_cost(stock.product)
    reset_layers!(stock, unit, as_of)
    InventoryPosting.revalue!(stock, stock.quantity * unit, movement_type: 'opening', user: user, occurred_on: as_of,
                                                            notes: "Opening balance at #{unit.round(4)}/unit")
  end

  # A standard product's stock moves to the new standard; the difference is a revaluation.
  def standard_changed!(product)
    return unless product.costing_method == 'standard' && product.standard_cost && started?

    previous, current = product.saved_change_to_standard_cost
    notes = "Standard cost #{previous&.round(4) || 'none'} → #{current.round(4)}"
    product.location_products.where.not(quantity: 0).find_each do |stock|
      InventoryPosting.revalue!(stock, stock.quantity * current, source: product, notes: notes)
    end
  end

  # Stock carries over at its current value; standard revalues to standard, and FIFO starts from one
  # layer at the current average.
  def method_changed!(group)
    return unless started?

    notes = "Costing method #{group.saved_change_to_costing_method.join(' → ')}"
    LocationProduct.joins(:product).where(products: { category: group.name }).includes(:product, :location)
                   .find_each { |stock| switch_method!(stock, group, notes) }
  end

  def switch_method!(stock, group, notes)
    standard = stock.product.standard_cost
    reset_layers!(stock, stock.average_cost || stock.product.cost_per_unit || 0.to_d, Date.current,
                  fifo: group.costing_method == 'fifo')
    return unless group.costing_method == 'standard' && standard

    InventoryPosting.revalue!(stock, stock.quantity * standard, source: group, notes: notes)
  end

  def tracked_stock
    non_inventory = Product.joins(:reporting_group).where(reporting_groups: { item_type: 'non_inventory' })
    LocationProduct.includes(:product, :location).where.not(quantity: 0)
                   .where.not(product_id: non_inventory.select(:id))
  end

  def opening_cost(product)
    basis = product.costing_method == 'standard' ? product.standard_cost : product.cost_per_unit
    (basis || product.cost_per_unit || product.standard_cost || 0).to_d
  end

  # Closes the location's FIFO layers; with fifo, starts one layer holding the stock on hand.
  def reset_layers!(stock, unit, date, fifo: stock.product.costing_method == 'fifo')
    InventoryCostLayer.open.where(product_id: stock.product_id, location_id: stock.location_id).find_each do |layer|
      layer.update!(remaining_quantity: 0)
    end
    return unless fifo && stock.quantity.positive?

    InventoryCostLayer.create!(product_id: stock.product_id, location_id: stock.location_id, received_on: date,
                               quantity: stock.quantity, remaining_quantity: stock.quantity, unit_cost: unit)
  end
end
