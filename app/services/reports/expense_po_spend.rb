module Reports
  # Expense PO lines (equipment parts, repairs, supplies) ordered in the period, with the equipment and GL account
  # each was charged to. Sort or pivot the CSV by equipment or account.
  class ExpensePoSpend < Base
    report title: 'Expense PO spend', area: :purchasing,
           description: 'Expense purchase order lines ordered in the period, by equipment and GL account.',
           filters: %i[dates vendor_id location_id]

    def self.location_label
      'Site'
    end

    def columns
      [column(:po, 'PO'), column(:date, 'Ordered', :date), column(:vendor, 'Vendor'), column(:status, 'Status'),
       column(:equipment, 'Equipment'), column(:gl_account, 'GL account'), column(:account_name, 'Account'),
       column(:description, 'Description'), column(:part_number, 'Part #'),
       column(:amount, 'Amount', :currency, total: true)]
    end

    def rows
      @rows ||= scope.includes(:expense_account, :equipment, :location, purchase_order: :vendor)
                     .order('purchase_orders.created_at', :id).map { |line| line_row(line) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.purchase_order_path(row[:po_id]) if column.key == :po
    end

    private

    def scope
      scope = PurchaseOrderLineItem.joins(:purchase_order).merge(orders)
      filters[:location_id] ? scope.where(location_id: filters[:location_id]) : scope
    end

    def orders
      orders = PurchaseOrder.expense.where(voided_at: nil, created_at: time_range).where.not(status: 'cancelled')
      filters[:vendor_id] ? orders.where(vendor_id: filters[:vendor_id]) : orders
    end

    def line_row(line)
      po_columns(line.purchase_order).merge(
        equipment: line.equipment&.name, gl_account: line.gl_account_code, account_name: line.expense_account&.name,
        description: line.product_name, part_number: line.vendor_part_number, amount: line.total_cost.to_d
      )
    end

    def po_columns(order)
      { po_id: order.id, po: order.display_number, date: order.created_at.to_date, vendor: order.vendor&.name,
        status: order.status == 'submitted' ? 'Sent to vendor' : order.status.humanize }
    end
  end
end
