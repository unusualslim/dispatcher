module Reports
  class LateOrders < Base
    report title: 'Orders invoiced late', area: :sales,
           description: 'Orders invoiced in the period with order, required and invoice dates. ' \
                        '"Problems only" shows those invoiced after the required date.',
           filters: %i[dates customer_id only_problems]

    def columns
      [column(:order_no, 'Order'), column(:customer, 'Customer'), column(:ship_to, 'Ship-to'),
       column(:order_date, 'Ordered', :date), column(:required, 'Required', :date),
       column(:invoice_date, 'Invoiced', :date), column(:days, 'Days', :number),
       column(:days_late, 'Days late', :number)]
    end

    def rows
      @rows ||= scope.includes(:customer, :location).order(:invoice_date, :id).map { |order| order_row(order) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.customer_order_path(row[:order]) if column.key == :order_no
    end

    private

    def scope
      scope = CustomerOrder.where(invoice_date: range).where.not(order_status: FinancialDashboard::Sales::CANCELLED)
      scope = scope.where(customer_id: filters[:customer_id]) if filters[:customer_id]
      filters.only_problems? ? scope.where('invoice_date > required_delivery_date') : scope
    end

    def order_row(order)
      { order: order, order_no: order.external_order_no || "##{order.id}", customer: order.customer&.name,
        ship_to: order.location&.company_name, order_date: order.order_date&.to_date,
        required: order.required_delivery_date, invoice_date: order.invoice_date, days: days(order),
        days_late: days_late(order) }
    end

    def days(order)
      (order.invoice_date - order.order_date.to_date).to_i if order.order_date
    end

    def days_late(order)
      late = order.required_delivery_date && (order.invoice_date - order.required_delivery_date).to_i
      late if late&.positive?
    end
  end
end
