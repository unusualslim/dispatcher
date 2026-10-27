module Reports
  class PpvByProduct < Base
    report title: 'Purchase price variance by product', area: :purchasing,
           description: 'Receipts of standard-costed products in the period: what was paid against standard cost.',
           filters: %i[dates product_id location_id]

    def columns
      [column(:product_id, 'Product'), column(:name, 'Name'), column(:quantity, 'Received', :number, total: true),
       column(:actual, 'Actual cost', :currency, total: true), column(:standard, 'At standard', :currency, total: true),
       column(:variance, 'Variance', :currency, total: true), column(:variance_pct, 'Variance %', :percent)]
    end

    SUMS = [InventoryValuation::SIGNED_QUANTITY, InventoryValuation::SIGNED_VALUE, 'SUM(variance_amount)'].freeze

    def rows
      @rows ||= begin
        sums = sums_by(scope, 'product_id', SUMS)
        products = Product.where(id: sums.map(&:first)).index_by(&:id)
        sums.map { |id, *values| ppv_row(id, products[id], values.map(&:to_d)) }.sort_by { |row| -row[:variance].abs }
      end
    end

    private

    def scope
      scope = InventoryTransaction.where(movement_type: 'receipt', occurred_on: range).where.not(variance_amount: nil)
      scope = scope.where(product_id: filters[:product_id]) if filters[:product_id]
      filters[:location_id] ? scope.where(location_id: filters[:location_id]) : scope
    end

    def ppv_row(id, product, (qty, standard, variance))
      { product_id: id, name: product&.name, quantity: qty, actual: standard + variance, standard: standard,
        variance: variance, variance_pct: (variance / standard if standard.nonzero?) }
    end
  end
end
