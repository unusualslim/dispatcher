module Reports
  # Lost and lagging sales: each account's net sales in the period against the same number of days just before it,
  # flagging accounts (or account + item pairs) that stopped buying or dropped.
  class CustomerSalesTrend < Base
    include SalesLines

    VIEWS = { 'customer' => 'By customer', 'customer_product' => 'By customer and item' }.freeze
    DROP = -0.2 # a fall of 20% or more is flagged

    report title: 'Lost and lagging sales', area: :sales, flag: :financial_dashboard,
           description: 'Net sales per customer (or customer and item) against the same length of time just ' \
                        'before, flagging accounts that stopped buying or fell 20% or more.',
           filters: %i[dates view item_type product_id category]

    def self.default_from(today)
      today - 90.days
    end

    def columns
      item = by_product? ? [column(:product_id, 'Item'), column(:description, 'Description')] : []
      [column(:customer, 'Customer'), *item,
       column(:prior, 'Prior period', :currency, total: true), column(:current, 'This period', :currency, total: true),
       column(:change, 'Change', :currency, total: true), column(:change_pct, 'Change %', :percent),
       column(:flag, 'Flag')]
    end

    def rows
      @rows ||= begin
        now = sums(range)
        before = sums(prior_range)
        (now.keys | before.keys).map { |key| row(key, now.fetch(key, 0.to_d), before.fetch(key, 0.to_d)) }
                                .sort_by { |r| r[:change] }
      end
    end

    private

    def by_product?
      filters[:view] == 'customer_product'
    end

    def prior_range
      days = (range.end - range.begin).to_i + 1
      (range.begin - days)..(range.begin - 1)
    end

    # { [customer_id(, product code)] => net sales }
    def sums(period)
      group = ['customer_orders.customer_id', *('customer_order_products.product_name' if by_product?)]
      sales_lines(period).group(*group.map { |g| Arel.sql(g) }).sum(Arel.sql(S::NET))
                         .transform_keys { |key| Array(key) }.transform_values(&:to_d)
    end

    def row(key, current, prior)
      customer_id, code = key
      change = current - prior
      { customer: customers[customer_id]&.name || '(no customer)', product_id: code,
        description: (products[code]&.name if code), prior: prior, current: current, change: change,
        change_pct: (change / prior if prior.positive?), flag: flag(current, prior, change) }
    end

    def flag(current, prior, change)
      return 'Stopped buying' if prior.positive? && current <= 0
      return 'New' if prior <= 0 && current.positive?

      'Down' if prior.positive? && change / prior <= DROP
    end

    def customers
      @customers ||= Customer.all.index_by(&:id)
    end

    def products
      @products ||= Product.all.index_by(&:id)
    end
  end
end
