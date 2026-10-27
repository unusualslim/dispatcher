class InventoryPosting
  # FIFO cost layers for one product at one location. Issues use up the oldest layers first and record
  # what they drew, so a reversal can return it.
  class Layers
    def initialize(product, location)
      @scope = InventoryCostLayer.where(product_id: product.id, location_id: location.id)
      @product = product
      @location = location
    end

    # The oldest open layer's cost, else the latest layer's, else the fallback.
    def current_cost(fallback)
      @scope.open.oldest_first.first&.unit_cost || @scope.order(:id).last&.unit_cost || fallback
    end

    def add!(txn, qty, unit_cost)
      InventoryCostLayer.create!(product_id: @product.id, location: @location, inventory_transaction: txn,
                                 received_on: txn.occurred_on, quantity: qty, remaining_quantity: qty,
                                 unit_cost: unit_cost)
    end

    # [value, draws]. Anything beyond the open layers goes out at the latest cost.
    def draw(qty, fallback)
      draws = take_oldest(qty)
      shortfall = qty - draws.sum { |_, take| take }
      [draws.sum { |layer, take| take * layer.unit_cost } + (shortfall * current_cost(fallback)), draws]
    end

    # [value, draws, shortfall] for reversing a movement: a receipt comes back out of its layers, an issue
    # goes back into the layers it drew from.
    def undo(original, fallback)
      return [*take_back(original, fallback), nil] if original.direction == 'in'

      [original.total_cost, [], put_back(original)]
    end

    # After a reversal posts: records what it drew, and adds back as a new layer what the issue took beyond
    # the layers.
    def undone!(txn, draws, shortfall)
      save_draws!(txn, draws)
      add!(txn, shortfall, txn.unit_cost) if shortfall&.positive?
    end

    def save_draws!(txn, draws)
      draws.each do |layer, qty|
        txn.inventory_layer_draws.create!(inventory_cost_layer: layer, quantity: qty, unit_cost: layer.unit_cost)
      end
    end

    private

    def take_oldest(qty)
      remaining = qty
      @scope.open.oldest_first.lock.each_with_object([]) do |layer, draws|
        break draws if remaining.zero?

        take = [layer.remaining_quantity, remaining].min
        layer.update!(remaining_quantity: layer.remaining_quantity - take)
        draws << [layer, take]
        remaining -= take
      end
    end

    # A receipt being reversed: [value, draws] taking it from its own layer first, then the oldest.
    def take_back(original, fallback)
      own = @scope.find_by(inventory_transaction_id: original.id)
      from_own = own ? [own.remaining_quantity, original.quantity].min : 0
      own&.update!(remaining_quantity: own.remaining_quantity - from_own)
      value, draws = draw(original.quantity - from_own, fallback)
      draws.unshift([own, from_own]) if from_own.positive?
      [(from_own * original.unit_cost) + value, draws]
    end

    # An issue being reversed: returns what it drew to the same layers. Returns the quantity it took
    # beyond the layers (the caller adds it back as a new layer).
    def put_back(original)
      drawn = original.inventory_layer_draws.includes(:inventory_cost_layer).sum do |draw|
        layer = draw.inventory_cost_layer
        layer.update!(remaining_quantity: layer.remaining_quantity + draw.quantity)
        draw.quantity
      end
      original.quantity - drawn
    end
  end
end
