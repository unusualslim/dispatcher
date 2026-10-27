class InventoryPosting
  # Writes a movement: moves the location's quantity and value, keeps products.current_stock as the total
  # across locations, and records the InventoryTransaction with the balance afterwards.
  module Recording
    private

    # qty signed; value is the movement's cost (positive).
    def record!(stock, qty, value, movement_type, details)
      move_stock!(stock, qty, qty.positive? ? value : -value)
      InventoryTransaction.create!(
        transaction_attrs(stock, movement_type, details)
          .merge(quantity: qty.abs, direction: qty.positive? ? 'in' : 'out', unit_cost: (value / qty.abs).round(6),
                 total_cost: value.round(4), variance_amount: details[:variance]&.round(4))
      )
    end

    def move_stock!(stock, qty, value)
      stock.update!(quantity: stock.quantity + qty, inventory_value: stock.inventory_value + value)
      product.update!(current_stock: LocationProduct.where(product_id: product.id).sum(:quantity))
    end

    def transaction_attrs(stock, movement_type, details)
      { product: product, location: location, movement_type: movement_type, balance_quantity: stock.quantity,
        balance_value: stock.inventory_value, occurred_on: details[:occurred_on] || Date.current,
        transactable: details[:source], reference_number: details[:reference], notes: details[:notes],
        created_by_id: details[:user]&.id, reversal_of: details[:reversal_of] }
    end
  end
end
