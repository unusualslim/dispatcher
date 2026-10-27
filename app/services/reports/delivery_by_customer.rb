module Reports
  class DeliveryByCustomer < Base
    DAYS = 'invoice_date - CAST(order_date AS date)'.freeze

    report title: 'Delivery time by customer', area: :sales,
           description: 'Average days from order to invoice and the share invoiced by the required date, per customer.',
           filters: %i[dates customer_id]

    def columns
      [column(:customer, 'Customer'), column(:orders, 'Orders', :number, total: true),
       column(:average_days, 'Avg days', :days), column(:on_time, 'On time', :percent),
       column(:late, 'Late', :number, total: true)]
    end

    SUMS = ['COUNT(*)', "AVG(#{DAYS})",
            'AVG(CASE WHEN required_delivery_date IS NULL THEN NULL ' \
            'WHEN invoice_date <= required_delivery_date THEN 1.0 ELSE 0 END)',
            'COUNT(*) FILTER (WHERE invoice_date > required_delivery_date)'].freeze

    def rows
      @rows ||= begin
        sums = invoiced.group(:customer_id).pluck(:customer_id, *SUMS.map { |sql| Arel.sql(sql) })
        customers = Customer.where(id: sums.map(&:first)).index_by(&:id)
        sums.map { |id, *values| delivery_row(customers[id], *values) }.sort_by { |row| -row[:orders] }
      end
    end

    private

    def invoiced
      scope = CustomerOrder.where(invoice_date: range).where.not(order_date: nil)
                           .where.not(order_status: FinancialDashboard::Sales::CANCELLED)
      filters[:customer_id] ? scope.where(customer_id: filters[:customer_id]) : scope
    end

    def delivery_row(customer, orders, days, on_time, late)
      { customer: customer&.name || 'No customer (own sites)', orders: orders, average_days: days&.to_d,
        on_time: on_time&.to_d, late: late }
    end
  end
end
