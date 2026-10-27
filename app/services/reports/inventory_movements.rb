module Reports
  class InventoryMovements < Base
    report title: 'Inventory movements', area: :inventory,
           description: 'Costed stock movements in the period: receipts, sales, production, adjustments, PDI sync ' \
                        'differences and revaluations, with quantity and value.',
           filters: %i[dates product_id location_id movement_type]

    def columns
      [column(:date, 'Date', :date), column(:type, 'Type'), column(:product, 'Product'), column(:location, 'Location'),
       column(:quantity, 'Quantity', :decimal, total: true), column(:unit_cost, 'Unit cost', :price),
       column(:value, 'Value', :currency, total: true), column(:variance, 'Variance', :currency, total: true),
       column(:reference, 'Reference')]
    end

    def rows
      @rows ||= scope.includes(:product, :location).order(:occurred_on, :id).map { |move| movement_row(move) }
    end

    private

    def movement_row(move)
      { date: move.occurred_on, type: move.movement_type_label + (move.reversal_of_id ? ' (reversal)' : ''),
        product: move.product.name, location: move.location&.company_name,
        quantity: (move.signed_quantity unless move.value_only?), unit_cost: move.unit_cost,
        value: move.signed_value, variance: move.variance_amount, reference: move.reference_number }
    end

    def scope
      scope = InventoryTransaction.costed.where(occurred_on: range)
      %i[product_id location_id movement_type].each do |key|
        scope = scope.where(key => filters[key]) if filters[key]
      end
      scope
    end
  end
end
