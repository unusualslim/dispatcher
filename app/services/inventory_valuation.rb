# Inventory on hand and its value by product and location, as of a date: today's balances with later
# movements taken back out. Also the period's movements by type, purchase price variance and PDI sync
# differences (stock PDI counted that the app didn't see move).
class InventoryValuation
  Row = Struct.new(:product, :location, :quantity, :value, keyword_init: true) do
    def unit_cost = (value / quantity if quantity.nonzero?)
  end

  SIGNED_QUANTITY = "SUM(CASE WHEN direction = 'in' THEN quantity ELSE -quantity END)".freeze
  SIGNED_VALUE = "SUM(CASE WHEN direction = 'in' THEN total_cost ELSE -total_cost END)".freeze

  attr_reader :as_of, :location_id, :group_name

  def initialize(as_of: Date.current, location_id: nil, group_name: nil)
    @as_of = as_of
    @location_id = location_id.presence
    @group_name = group_name.presence
  end

  # { ReportingGroup or nil => [Row] }, rows with nothing on hand left out.
  def rows_by_group
    @rows_by_group ||= rows.group_by { |row| row.product.reporting_group }
                           .sort_by { |group, _| [group ? 0 : 1, group&.position || 0, group&.name.to_s] }.to_h
  end

  def total_value
    rows.sum(0.to_d, &:value)
  end

  # { movement_type => [net quantity, net value] } for movements dated from..as_of (in positive).
  def movements_by_type(from)
    period(from).group(:movement_type).pluck(:movement_type, Arel.sql(SIGNED_QUANTITY), Arel.sql(SIGNED_VALUE))
                .to_h { |type, qty, value| [type, [qty.to_d, value.to_d]] }
  end

  # Receipt cost above standard (positive = unfavorable), by product.
  def purchase_price_variance(from)
    totals = period(from).where(movement_type: 'receipt').group(:product_id).sum(:variance_amount)
                         .reject { |_, variance| variance.zero? }
    products = Product.where(id: totals.keys).index_by(&:id)
    totals.map { |id, variance| [products[id], variance] }.sort_by { |_, variance| -variance.abs }
  end

  private

  def rows
    @rows ||= scope(LocationProduct.includes(product: :reporting_group, location: []))
              .filter_map { |stock| row(stock, *later_movements.fetch([stock.product_id, stock.location_id], [0, 0])) }
              .sort_by { |row| [row.product.name.to_s, row.location.company_name.to_s] }
  end

  # The location's stock as of the date: today's balance less what moved after it.
  def row(stock, qty_after, value_after)
    qty = stock.quantity.to_d - qty_after
    value = stock.inventory_value.to_d - value_after
    return if qty.zero? && value.zero?

    Row.new(product: stock.product, location: stock.location, quantity: qty, value: value)
  end

  # { [product_id, location_id] => [signed qty, signed value] } dated after as_of.
  def later_movements
    @later_movements ||= scope(InventoryTransaction.where(occurred_on: as_of.next_day..))
                         .group(:product_id, :location_id)
                         .pluck(:product_id, :location_id, Arel.sql(SIGNED_QUANTITY), Arel.sql(SIGNED_VALUE))
                         .to_h { |product_id, loc_id, qty, value| [[product_id, loc_id], [qty.to_d, value.to_d]] }
  end

  def period(from)
    scope(InventoryTransaction.costed.where(occurred_on: from..as_of))
  end

  # Non-inventory products, and the location / group filters.
  def scope(relation)
    table = relation.table_name
    relation = relation.where(location_id: location_id) if location_id
    non_inventory = Product.joins(:reporting_group).where(reporting_groups: { item_type: 'non_inventory' })
    tracked = group_name ? Product.where(category: group_name) : Product.all
    relation.where("#{table}.product_id" => tracked.where.not(id: non_inventory.select(:id)).select(:id))
  end
end
