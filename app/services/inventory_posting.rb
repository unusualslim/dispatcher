# Posts inventory movements at cost. Every stock change goes through here: it moves the location's
# quantity, values the movement by the product's costing method (its reporting group's choice) and
# records an InventoryTransaction carrying the cost and the location's balance afterwards.
#
#   weighted_average  receipts at actual cost re-average the location; issues go out at the average
#   standard          everything at products.standard_cost; a receipt's actual − standard is variance (PPV)
#   fifo              receipts add a cost layer; issues use up the oldest layers first (InventoryPosting::Layers)
#
# Movements without a location post at the main warehouse (PDI site 0002).
# Details (all optional): source, reference, notes, user, occurred_on.
class InventoryPosting
  include Recording

  class NoLocation < StandardError; end

  # quantity is signed: positive adds stock, negative removes it. unit_cost is a receipt's actual cost
  # (PO line, production cost); without one, stock comes in at the location's current cost.
  def self.post!(product:, location:, quantity:, movement_type:, **details)
    new(product, location).post!(quantity.to_d, movement_type, **details)
  end

  # Undoes a movement at exactly its original value (FIFO puts the layers back).
  def self.reverse!(original, source:, reference:, user: nil)
    new(original.product, original.location).reverse!(original, source: source, reference: reference, user: user)
  end

  # Changes a location's value without moving quantity (opening balances, standard or method changes).
  def self.revalue!(location_product, value, movement_type: 'revaluation', **details)
    new(location_product.product, location_product.location).revalue!(value.to_d, movement_type, **details)
  end

  def self.main_warehouse
    Location.find_by(pdi_site_code: PdiOrders::Warehouses::MAIN_SITE)
  end

  attr_reader :product, :location

  def initialize(product, location)
    @product = product
    @location = location || self.class.main_warehouse ||
                raise(NoLocation, "No location for #{product.id}, and no main warehouse (PDI site 0002)")
  end

  def costing_method
    @costing_method ||= product.costing_method
  end

  def post!(qty, movement_type, unit_cost: nil, **details)
    return if qty.zero?

    ActiveRecord::Base.transaction do
      stock = stock_row
      if qty.positive?
        receive!(stock, qty, unit_cost&.to_d, movement_type, details)
      else
        issue!(stock, -qty, movement_type, details)
      end
    end
  end

  def reverse!(original, source:, reference:, user: nil)
    details = { source: source, reference: reference, user: user, reversal_of: original,
                notes: "Reverses #{reference}: #{original.notes}".first(255) }
    # Older moves have no cost: they reverse at today's cost.
    if original.total_cost.nil?
      return post!(-original.signed_quantity, original.movement_type || 'adjustment', **details)
    end

    ActiveRecord::Base.transaction { undo!(stock_row, original, details) }
  end

  def revalue!(value, movement_type, **details)
    ActiveRecord::Base.transaction do
      stock = stock_row
      delta = (value - stock.inventory_value.to_d).round(4)
      next if delta.zero? && movement_type == 'revaluation'

      stock.update!(inventory_value: value)
      InventoryTransaction.create!(
        transaction_attrs(stock, movement_type, details)
          .merge(quantity: 0, direction: delta.negative? ? 'out' : 'in', total_cost: delta.abs, variance_amount: delta)
      )
    end
  end

  # What one unit is worth here right now.
  def current_cost(stock = stock_row)
    return product.standard_cost || fallback_cost if costing_method == 'standard'
    return layers.current_cost(fallback_cost) if fifo?

    average = stock.average_cost
    average&.positive? ? average : fallback_cost
  end

  private

  def fifo? = costing_method == 'fifo'

  def stock_row
    LocationProduct.lock.find_or_create_by!(location_id: location.id, product_id: product.id)
  end

  def layers
    @layers ||= Layers.new(product, location)
  end

  # PDI's weighted average, else the standard; zero when the product has neither.
  def fallback_cost
    product.cost_per_unit || product.standard_cost || 0.to_d
  end

  # Standard books at standard and keeps the difference from actual as variance.
  def receive!(stock, qty, actual_cost, movement_type, details)
    standard = product.standard_cost if costing_method == 'standard'
    unit = standard || actual_cost || current_cost(stock)
    variance = standard && actual_cost && ((actual_cost - standard) * qty)
    txn = record!(stock, qty, qty * unit, movement_type, details.merge(variance: variance))
    layers.add!(txn, qty, unit) if fifo?
    txn
  end

  def issue!(stock, qty, movement_type, details)
    value, draws = fifo? ? layers.draw(qty, fallback_cost) : [issue_value(stock, qty), []]
    record!(stock, -qty, value, movement_type, details).tap { |txn| layers.save_draws!(txn, draws) }
  end

  # Weighted average takes the whole value when the last of the stock goes.
  def issue_value(stock, qty)
    return stock.inventory_value.to_d if costing_method == 'weighted_average' && qty == stock.quantity.to_d

    qty * current_cost(stock)
  end

  # The opposite movement at the original's value; FIFO takes or returns the same layers.
  def undo!(stock, original, details)
    value, draws, shortfall = fifo? ? layers.undo(original, fallback_cost) : [original.total_cost, [], nil]
    txn = record!(stock, -original.signed_quantity, value, original.movement_type,
                  details.merge(variance: original.variance_amount && -original.variance_amount))
    layers.undone!(txn, draws, shortfall) if fifo?
    txn
  end
end
