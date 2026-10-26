# Filters and sorts the Products page (ProductsController#index). Params:
#   query, type (finished/raw/all), category[] (several), status (critical/low/ok), in_stock, inactive,
#   unit, bom (with/without), vendor (with/without), sales (open/3/6/12/never), sort ("<column>_asc|desc").
class ProductListQuery
  KEYS = %w[query type category status in_stock inactive unit bom vendor sales sort].freeze
  SALES = { 'open' => 'On open orders', '3' => 'Ordered in last 3 months', '6' => 'Ordered in last 6 months',
            '12' => 'Ordered in last 12 months', 'never' => 'Never ordered' }.freeze

  ON_ORDER_SQL = <<~SQL.squish.freeze
    COALESCE((SELECT SUM(poli.quantity) FROM purchase_order_line_items poli
              JOIN purchase_orders po ON po.id = poli.purchase_order_id
              WHERE poli.product_id = products.id
                AND po.status IN ('draft','pending_approval','approved','submitted')), 0)
  SQL

  COMMITTED_SQL = <<~SQL.squish.freeze
    COALESCE((SELECT SUM(poc.quantity) FROM production_order_components poc
              JOIN production_orders pro ON pro.id = poc.production_order_id
              WHERE poc.product_id = products.id AND pro.status IN ('created','in_progress')), 0)
  SQL

  ORDERED_SINCE = 'COALESCE(customer_orders.order_date, customer_orders.created_at) >= ?'.freeze

  def initialize(params, warehouse: nil)
    @params = params
    @warehouse = warehouse
  end

  def relation
    scope = %i[search by_type by_category by_status by_flags by_unit by_links by_sales]
            .reduce(Product.all) { |rel, filter| send(filter, rel) }
    scope.order(Arel.sql("#{sort_sql} NULLS LAST, products.name ASC"))
         .select("products.*, (#{stock_sql}) AS warehouse_on_hand")
  end

  # Selected categories (the form sends category[]; older links sent one).
  def categories
    Array(@params[:category]).compact_blank
  end

  # On-hand quantity: the selected warehouse's, else the global current_stock.
  def stock_sql
    return 'products.current_stock' unless @warehouse

    'COALESCE((SELECT quantity FROM location_products ' \
      "WHERE location_id = #{@warehouse.id.to_i} AND product_id = products.id), 0)"
  end

  private

  def search(rel)
    q = @params[:query].presence
    q ? rel.where('products.name ILIKE :q OR products.id ILIKE :q', q: "%#{q}%") : rel
  end

  def by_type(rel)
    case @params[:type]
    when 'raw' then rel.where(is_raw_material: true)
    when 'all' then rel
    else rel.where(is_raw_material: false) # finished goods by default
    end
  end

  def by_category(rel)
    categories.any? ? rel.where(category: categories) : rel
  end

  def by_flags(rel)
    rel = rel.where("(#{stock_sql}) > 0") if @params[:in_stock] == '1'
    @params[:inactive] == '1' ? rel : rel.active
  end

  def by_unit(rel)
    @params[:unit].present? ? rel.where(unit_of_measurement: @params[:unit]) : rel
  end

  # Has / lacks a BOM; has / lacks a vendor.
  def by_links(rel)
    rel = with_or_without(rel, @params[:bom], ProductComponent.select(:product_id))
    with_or_without(rel, @params[:vendor], ProductVendor.select(:product_id))
  end

  def with_or_without(rel, choice, ids)
    case choice
    when 'with' then rel.where(id: ids)
    when 'without' then rel.where.not(id: ids)
    else rel
    end
  end

  # Critical: on hand + on order can't cover committed. Low: covered, but on hand at/below reorder point.
  def by_status(rel)
    projected = "((#{stock_sql}) + #{ON_ORDER_SQL})"
    covered = "reorder_point IS NOT NULL AND #{projected} >= (#{COMMITTED_SQL})"
    case @params[:status]
    when 'critical' then rel.where("reorder_point IS NOT NULL AND #{projected} < (#{COMMITTED_SQL})")
    when 'low' then rel.where("#{covered} AND (#{stock_sql}) <= reorder_point")
    when 'ok' then rel.where("#{covered} AND (#{stock_sql}) > reorder_point")
    else rel
    end
  end

  def by_sales(rel)
    case @params[:sales]
    when 'open' then rel.where(id: sold.where(customer_orders: { order_status: CustomerOrder::ACTIVE_STATUSES }))
    when '3', '6', '12' then rel.where(id: sold.where(ORDERED_SINCE, @params[:sales].to_i.months.ago))
    when 'never' then rel.where.not(id: sold)
    else rel
    end
  end

  # Product IDs on customer order lines.
  def sold
    CustomerOrderProduct.joins(:customer_order).where.not(product_id: nil).select(:product_id)
  end

  def sort_sql
    column, direction = @params[:sort].to_s.match(/\A(\w+?)_(asc|desc)\z/)&.captures
    expression = sort_columns[column] || 'products.name'
    "#{expression} #{direction == 'desc' ? 'DESC' : 'ASC'}"
  end

  def sort_columns
    stock = "(#{stock_sql})"
    { 'id' => 'products.id', 'name' => 'products.name', 'category' => "COALESCE(products.category, '')",
      'type' => 'products.is_raw_material', 'unit' => "COALESCE(products.unit_of_measurement, '')",
      'stock' => stock, 'on_order' => ON_ORDER_SQL, 'committed' => COMMITTED_SQL,
      'available' => "(#{stock} + #{ON_ORDER_SQL} - #{COMMITTED_SQL})", 'reorder' => 'products.reorder_point',
      'cost' => 'products.cost_per_unit', 'std_cost' => 'products.standard_cost' }
  end
end
