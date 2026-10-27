module Reports
  class QualityResults < Base
    report title: 'Quality results', area: :production,
           description: 'Quality check results recorded in the period. "Problems only" shows results out of range.',
           filters: %i[dates product_id only_problems]

    def columns
      [column(:tested, 'Tested', :date), column(:order_no, 'Production order'), column(:lot, 'Lot'),
       column(:product, 'Product'), column(:check, 'Check'), column(:result, 'Result'), column(:target, 'Target'),
       column(:in_range, 'In range'), column(:review, 'Review')]
    end

    def rows
      @rows ||= scope.includes(production_order: :product).order(:tested_at).map do |result|
        order = result.production_order
        { order: order, tested: result.tested_at.to_date, order_no: order.number, lot: order.lot_number,
          product: order.product&.name, check: result.name, result: result.display_value,
          target: result.target_label, in_range: result.in_range? ? 'Yes' : 'No', review: review(result) }
      end
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.production_order_path(row[:order]) if column.key == :order_no
    end

    private

    def scope
      scope = QualityResult.where(tested_at: time_range)
      if filters[:product_id]
        scope = scope.joins(:production_order).where(production_orders: { product_id: filters[:product_id] })
      end
      filters.only_problems? ? scope.out_of_range : scope
    end

    def review(result)
      return '' if result.in_range?

      result.reviewed? ? "Reviewed: #{result.resolution}" : 'Waiting for review'
    end
  end
end
