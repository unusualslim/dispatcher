module Reports
  # Job contract pricing (the operations group's "Job Contract" sheet): every locked quote price in effect on the
  # report's end date, with the item's standard cost and current cost and the margin on each. Items not made yet
  # (no standard or average cost) fall back to their BOM cost, so a new item still shows a cost.
  class ContractPrices < Base
    report title: 'Contract prices and margins', area: :sales, flag: :costs,
           description: 'Locked quote prices in effect, with standard cost, current cost and the margin on each.',
           filters: %i[customer_id product_id category]

    def columns
      [column(:customer, 'Customer'), column(:quote, 'Quote'), column(:product_id, 'Item'),
       column(:description, 'Description'), column(:package, 'UOM'), column(:price, 'Price', :price),
       column(:start, 'Start', :date), column(:expires, 'Expires', :date),
       column(:standard_cost, 'Standard cost', :price), column(:standard_margin, 'Margin on standard', :percent),
       column(:current_cost, 'Current cost', :price), column(:current_margin, 'Margin on current', :percent),
       column(:quoted_cost, 'Cost when quoted', :price)]
    end

    def rows
      @rows ||= lines.map { |line| row(line) }.sort_by { |r| [r[:customer].to_s, r[:product_id].to_s] }
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.quote_path(row[:quote_id]) if column.key == :quote
    end

    private

    def lines
      scope = QuoteProduct.locking_on(Date.current).includes(quote: :customer, product: :standard_cost_histories)
      scope = scope.where(quotes: { customer_id: filters[:customer_id] }) if filters[:customer_id]
      scope = scope.where(product_id: filters[:product_id]) if filters[:product_id]
      scope = scope.joins(:product).where(products: { category: filters[:category] }) if filters[:category]
      scope.to_a
    end

    def row(line)
      quote = line.quote
      product = line.product
      price = line.price&.to_d
      standard = product && (product.current_standard_cost || product.bom_standard_cost)
      current = product && (product.cost_per_unit&.to_d&.nonzero? || product.bom_standard_cost)
      { quote_id: quote.id, customer: quote.customer&.name, quote: quote.quote_number, product_id: line.product_id,
        description: product&.name || line.product_name, package: product&.pdi_package_code, price: price,
        start: quote.valid_from, expires: quote.lock_ended_on || quote.expiry_date, standard_cost: standard,
        standard_margin: margin(price, standard), current_cost: current, current_margin: margin(price, current),
        quoted_cost: line.basis_cost }
    end

    def margin(price, cost)
      (price - cost.to_d) / price if price&.positive? && cost
    end
  end
end
