module Reports
  class SalesByCustomer < Base
    include SalesLines

    report title: 'Sales by customer', area: :sales,
           description: 'Net sales, taxes and volume per customer for orders invoiced in the period.',
           filters: %i[dates item_type product_id location_id]

    def columns
      sales_columns([column(:customer, 'Customer'), column(:pdi_id, 'PDI #')]) + [column(:share, 'Share', :percent)]
    end

    def rows
      @rows ||= begin
        sums = sales_by('customer_orders.customer_id')
        customers = Customer.where(id: sums.map(&:first)).index_by(&:id)
        net_total = sums.sum { |row| row[3] }
        sums.map { |id, *values| customer_row(customers[id], values, net_total) }.sort_by { |row| -row[:net] }
      end
    end

    def link_for(row, column)
      return unless column.key == :customer && row[:customer_record]

      Rails.application.routes.url_helpers.customer_path(row[:customer_record])
    end

    private

    def customer_row(customer, values, net_total)
      { customer: customer&.name || 'No customer (own sites)', customer_record: customer,
        pdi_id: customer&.pdi_customer_id, **sales_values(*values),
        share: (values[2] / net_total if net_total.nonzero?) }
    end
  end
end
