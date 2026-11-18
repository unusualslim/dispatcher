module Reports
  # The item master with its activity dates: when each item was last sold, received and produced, with stock on
  # hand and standard cost, so slow and dead items stand out.
  class ItemActivity < Base
    SOLD_ON = 'COALESCE(customer_orders.invoice_date, customer_orders.order_date)'.freeze
    USAGE_DAYS = 90

    report title: 'Item master with last activity', area: :inventory,
           description: 'Every active item with on-hand stock, standard cost, when it was last sold, received ' \
                        'and produced, and days on hand at the last 90 days\' sales rate.',
           filters: %i[category item_type]

    def columns
      [column(:product_id, 'Item'), column(:description, 'Description'), column(:group, 'Group'),
       column(:package, 'UOM'), column(:on_hand, 'On hand', :decimal, total: true),
       column(:standard_cost, 'Standard cost', :price), column(:last_sold, 'Last sold', :date),
       column(:last_received, 'Last received', :date), column(:last_produced, 'Last produced', :date),
       column(:days_since_sold, 'Days since sold', :number), column(:daily_usage, 'Sold per day (90 d)', :decimal),
       column(:days_on_hand, 'Days on hand', :number)]
    end

    def rows
      @rows ||= products.map { |product| row(product) }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.product_path(row[:product_id]) if column.key == :product_id
    end

    private

    def products
      scope = Product.active.includes(:standard_cost_histories, :reporting_group).order(:id)
      scope = scope.where(category: filters[:category]) if filters[:category]
      if filters[:item_type]
        scope = scope.joins(:reporting_group).where(reporting_groups: { item_type: filters[:item_type] })
      end
      scope.to_a
    end

    def row(product)
      sold = last_sold[product.id]
      { product_id: product.id, description: product.name, group: product.category,
        package: product.pdi_package_code, on_hand: on_hand.fetch(product.id, 0).to_d,
        standard_cost: product.current_standard_cost, last_sold: sold, last_received: last_received[product.id],
        last_produced: last_produced[product.id], days_since_sold: sold && (Date.current - sold).to_i,
        **coverage(product) }
    end

    def on_hand
      @on_hand ||= LocationProduct.group(:product_id).sum(:quantity)
    end

    # Average sold per day over the last 90 days, and how many days the stock on hand lasts at that rate.
    def coverage(product)
      daily = recent_sales.fetch(product.id, 0).to_d / USAGE_DAYS
      stock = on_hand.fetch(product.id, 0).to_d
      { daily_usage: daily.nonzero?, days_on_hand: ((stock / daily).floor if daily.positive? && stock.positive?) }
    end

    def recent_sales
      @recent_sales ||= CustomerOrderProduct.joins(:customer_order)
                                            .where(customer_orders: { order_status: InventorySales::SHIPPED_STATUSES })
                                            .where(Arel.sql("#{SOLD_ON} >= ?"), Date.current - USAGE_DAYS)
                                            .group(:product_id)
                                            .sum(Arel.sql(FinancialDashboard::Sales::QTY))
    end

    def last_sold
      @last_sold ||= CustomerOrderProduct.joins(:customer_order)
                                         .where(customer_orders: { order_status: InventorySales::SHIPPED_STATUSES })
                                         .group(:product_id).maximum(Arel.sql(SOLD_ON))
                                         .transform_values { |date| date&.to_date }
    end

    def last_received
      @last_received ||= PurchaseOrderLineItem.joins(:purchase_order).where(purchase_orders: { voided_at: nil })
                                              .where.not(purchase_orders: { received_at: nil })
                                              .group(:product_id).maximum('purchase_orders.received_at')
                                              .transform_values(&:to_date)
    end

    def last_produced
      @last_produced ||= ProductionOrder.where(status: 'completed').group(:product_id).maximum(:date_completed)
                                        .transform_values { |date| date&.to_date }
    end
  end
end
