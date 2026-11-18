module Reports
  # ABC classes: items ranked by net sales in the period; A = the items making up the first 80% of sales,
  # B = the next 15%, C = the rest. Drives what gets counted, stocked and watched most.
  class AbcClasses < Base
    include SalesLines

    A_SHARE = 0.8
    B_SHARE = 0.95

    report title: 'ABC classes', area: :inventory, flag: :financial_dashboard,
           description: 'Items ranked by net sales: A = first 80% of sales, B = next 15%, C = the rest.',
           filters: %i[dates item_type location_id category]

    def self.default_from(today)
      today - 12.months
    end

    def columns
      [column(:rank, 'Rank', :number), column(:product_id, 'Item'), column(:description, 'Description'),
       column(:group, 'Group'), column(:quantity, 'Quantity', :decimal, total: true),
       column(:net, 'Net sales', :currency, total: true), column(:share, 'Share', :percent),
       column(:cumulative, 'Cumulative', :percent), column(:abc, 'Class')]
    end

    def rows
      @rows ||= begin
        sums = sales_by('customer_order_products.product_name').sort_by { |row| -row[3] }
        total = sums.sum { |row| row[3] }
        running = 0.to_d
        sums.each_with_index.map do |(code, _orders, qty, net, _tax), i|
          running += net
          abc_row(i + 1, code, [qty, net], total: total, running: running)
        end
      end
    end

    def link_for(row, column)
      return unless column.key == :product_id && products[row[:product_id]]

      Rails.application.routes.url_helpers.product_path(row[:product_id])
    end

    private

    def abc_row(rank, code, (qty, net), total:, running:)
      share = (net / total if total.positive?)
      before = total.positive? ? (running - net) / total : 0
      { rank: rank, product_id: code, description: products[code]&.name, group: products[code]&.category,
        quantity: qty, net: net, share: share, cumulative: (running / total if total.positive?),
        abc: if before < A_SHARE
               'A'
             elsif before < B_SHARE
               'B'
             else
               'C'
             end }
    end

    def products
      @products ||= Product.all.index_by(&:id)
    end
  end
end
