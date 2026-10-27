module Reports
  class PoSpendByVendor < Base
    SUMS = ['COUNT(DISTINCT purchase_orders.id)', 'COUNT(*)',
            'SUM(purchase_order_line_items.quantity * purchase_order_line_items.unit_cost)'].freeze

    report title: 'PO spend by vendor', area: :purchasing,
           description: 'Purchase orders received in the period and their value, per vendor.',
           filters: %i[dates location_id product_id]

    def columns
      [column(:vendor, 'Vendor'), column(:vendor_id, 'PDI #'), column(:pos, 'POs', :number, total: true),
       column(:lines, 'Lines', :number, total: true), column(:amount, 'Amount', :currency, total: true),
       column(:share, 'Share', :percent)]
    end

    def rows
      @rows ||= begin
        sums = sums_by(scope, 'purchase_orders.vendor_id', SUMS)
        vendors = Vendor.where(id: sums.map(&:first)).index_by(&:id)
        total = sums.sum { |row| row.last.to_d }
        sums.map { |id, *counts| vendor_row(vendors.fetch(id, id), counts, total) }.sort_by { |row| -row[:amount] }
      end
    end

    private

    def scope
      scope = PurchaseOrderLineItem.joins(:purchase_order)
                                   .where(purchase_orders: { voided_at: nil, received_at: time_range })
      scope = scope.where(purchase_orders: { location_id: filters[:location_id] }) if filters[:location_id]
      filters[:product_id] ? scope.where(product_id: filters[:product_id]) : scope
    end

    # vendor: the Vendor, or its ID when it's no longer in the app.
    def vendor_row(vendor, counts, total)
      pos, lines, amount = counts
      { vendor: vendor.try(:name) || vendor, vendor_id: vendor.try(:id) || vendor, pos: pos, lines: lines,
        amount: amount.to_d, share: (amount.to_d / total if total.nonzero?) }
    end
  end
end
