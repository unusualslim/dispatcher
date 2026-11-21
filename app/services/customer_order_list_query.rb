# Filters and sorts the Customer Orders list (CustomerOrdersController#index). Params (all optional):
#   search, quick (see QUICK), statuses[], customer_id, location_id (ship-to), ship_from_id, product_id, category,
#   date_field (order / delivery / invoice) + from / to, salesperson, carrier, source (pdi / app / sent),
#   dispatch (assigned / unassigned), freight_only, price_check (problems), sort ("<column>_asc|desc").
class CustomerOrderListQuery # rubocop:disable Metrics/ClassLength -- one small method per filter
  KEYS = %w[search quick statuses customer_id location_id ship_from_id product_id category date_field from to
            salesperson carrier source dispatch freight_only price_check sort per view].freeze

  QUICK = { 'open' => 'Open orders', 'unassigned' => 'Open, not on a dispatch', 'due_this_week' => 'Due this week',
            'overdue' => 'Overdue', 'needs_billing' => 'Needs billing', 'billed_this_month' => 'Billed this month',
            'on_hold' => 'On hold (expired / rejected)' }.freeze
  DATE_FIELDS = { 'order' => 'Order date', 'delivery' => 'Delivery date', 'invoice' => 'Invoice date' }.freeze
  SOURCES = { 'pdi' => 'From PDI', 'app' => 'Entered in the app', 'sent' => 'Sent to PDI from the app' }.freeze
  PRICE_PROBLEMS = %w[lock_mismatch rule_mismatch no_price].freeze
  PER_PAGE = [25, 50, 100, 200].freeze

  ORDER_DATE = 'COALESCE(customer_orders.order_date, customer_orders.created_at)'.freeze
  LINES = 'FROM customer_order_products cop WHERE cop.customer_order_id = customer_orders.id'.freeze

  # Sortable columns: key => SQL expression. Every column on the table has one.
  SORTS = {
    'order' => "COALESCE(NULLIF(customer_orders.external_order_no, ''), customer_orders.pdi_order_number, " \
               "LPAD(customer_orders.id::text, 10, '0'))",
    'status' => 'customer_orders.order_status',
    'customer' => '(SELECT c.name FROM customers c WHERE c.id = customer_orders.customer_id)',
    'ship_to' => '(SELECT l.company_name FROM locations l WHERE l.id = customer_orders.location_id)',
    'ship_from' => 'COALESCE((SELECT l.company_name FROM locations l ' \
                   'WHERE l.id = customer_orders.ship_from_location_id), ' \
                   "(SELECT MIN(cop.warehouse) #{LINES}))",
    'products' => '(SELECT MIN(COALESCE(p.name, cop.product_name)) FROM customer_order_products cop ' \
                  'LEFT JOIN products p ON p.id = cop.product_id WHERE cop.customer_order_id = customer_orders.id)',
    'qty' => "(SELECT SUM(cop.quantity) #{LINES})",
    'total' => "(SELECT SUM(cop.quantity * cop.price) #{LINES})",
    'order_date' => ORDER_DATE,
    'delivery' => 'customer_orders.required_delivery_date',
    'po' => 'customer_orders.customer_po_number',
    'invoice' => 'customer_orders.invoice_no',
    'invoice_date' => 'customer_orders.invoice_date',
    'salesperson' => 'customer_orders.salesperson',
    'carrier' => 'customer_orders.carrier',
    'driver' => 'customer_orders.pdi_driver',
    'dispatch' => '(SELECT MIN(dco.dispatch_id) FROM dispatch_customer_orders dco ' \
                  'WHERE dco.customer_order_id = customer_orders.id)'
  }.freeze
  DEFAULT_SORT = 'order_date_desc'.freeze

  def initialize(params, show_prices: true)
    @params = params
    @show_prices = show_prices
  end

  def relation
    filters = %i[search by_quick by_status by_customer by_ship_to by_ship_from by_product by_category by_dates
                 by_people by_source by_dispatch by_freight_only by_price_check]
    filters.reduce(CustomerOrder.all) { |rel, f| send(f, rel) }
           .order(sort_node, CustomerOrder.arel_table[:id].desc)
  end

  # The sort in effect ("order_date_desc" when none or an unknown one is given).
  def sort
    column, = parsed_sort
    column ? @params[:sort].to_s : DEFAULT_SORT
  end

  def per_page
    PER_PAGE.include?(@params[:per].to_i) ? @params[:per].to_i : 50
  end

  # How many filters are set beyond the defaults (for the "More filters" badge).
  def active_count
    (KEYS - %w[sort per view search quick statuses]).count { |k| value(k).present? }
  end

  private

  def value(key) = @params[key].presence

  def search(rel)
    q = @params[:search].to_s.strip.presence
    return rel unless q

    like = "%#{CustomerOrder.sanitize_sql_like(q)}%"
    rel.where(<<~SQL.squish, q: like, exact: q)
      customer_orders.external_order_no ILIKE :q OR customer_orders.pdi_order_number ILIKE :q
      OR customer_orders.invoice_no ILIKE :q OR customer_orders.customer_po_number ILIKE :q
      OR customer_orders.release_number ILIKE :q OR customer_orders.id::text = :exact
      OR customer_orders.customer_id IN (SELECT id FROM customers WHERE name ILIKE :q)
      OR customer_orders.location_id IN (SELECT id FROM locations WHERE company_name ILIKE :q OR city ILIKE :q)
    SQL
  end

  def by_quick(rel) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
    today = Date.current
    active = rel.where(order_status: CustomerOrder::ACTIVE_STATUSES)
    case @params[:quick]
    when 'open' then active
    when 'unassigned' then rel.merge(CustomerOrder.unassigned_open_orders)
    when 'due_this_week' then active.where(required_delivery_date: today..(today + 7))
    when 'overdue' then active.where(required_delivery_date: ...today)
    when 'needs_billing' then rel.where(order_status: ['Shipped', 'Released for Billing', 'Delivered'])
    when 'billed_this_month' then rel.where(order_status: 'Billed', created_at: today.beginning_of_month..)
    when 'on_hold' then rel.where(order_status: ['Expired', 'Rejected by Site'])
    else rel
    end
  end

  def by_status(rel)
    statuses = Array(@params[:statuses]).compact_blank
    statuses.any? ? rel.where(order_status: statuses) : rel
  end

  def by_customer(rel) = value(:customer_id) ? rel.where(customer_id: value(:customer_id)) : rel

  def by_ship_to(rel) = value(:location_id) ? rel.where(location_id: value(:location_id)) : rel

  # The order's ship-from, or a line shipping from that warehouse (PDI orders carry it per line).
  def by_ship_from(rel)
    id = value(:ship_from_id)
    return rel unless id

    rel.where('customer_orders.ship_from_location_id = :id OR customer_orders.id IN ' \
              '(SELECT customer_order_id FROM customer_order_products WHERE location_id = :id)', id: id)
  end

  def by_product(rel)
    id = value(:product_id)
    id ? rel.where(id: CustomerOrderProduct.where(product_id: id).select(:customer_order_id)) : rel
  end

  def by_category(rel)
    category = value(:category)
    return rel unless category

    rel.where(id: CustomerOrderProduct.where(product_id: Product.where(category: category).select(:id))
                                      .select(:customer_order_id))
  end

  def by_dates(rel)
    from = parse_date(@params[:from])
    to = parse_date(@params[:to])
    return rel unless from || to

    column = { 'delivery' => 'customer_orders.required_delivery_date', 'invoice' => 'customer_orders.invoice_date' }
             .fetch(@params[:date_field], "(#{ORDER_DATE} AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date")
    rel = rel.where("#{column} >= ?", from) if from
    rel = rel.where("#{column} <= ?", to) if to
    rel
  end

  def by_people(rel)
    rel = rel.where(salesperson: value(:salesperson)) if value(:salesperson)
    rel = rel.where(carrier: value(:carrier)) if value(:carrier)
    rel
  end

  def by_source(rel)
    case @params[:source]
    when 'pdi' then rel.where.not(external_order_no: [nil, ''])
    when 'app' then rel.where(external_order_no: [nil, ''])
    when 'sent' then rel.where.not(pdi_order_number: nil)
    else rel
    end
  end

  def by_dispatch(rel)
    on_dispatch = DispatchCustomerOrder.select(:customer_order_id)
    case @params[:dispatch]
    when 'assigned' then rel.where(id: on_dispatch)
    when 'unassigned' then rel.where.not(id: on_dispatch)
    else rel
    end
  end

  def by_freight_only(rel) = @params[:freight_only] == '1' ? rel.where(freight_only: true) : rel

  def by_price_check(rel)
    return rel unless @params[:price_check] == 'problems'

    rel.where(id: CustomerOrderProduct.where(price_check: PRICE_PROBLEMS).select(:customer_order_id))
  end

  def parse_date(text)
    Date.iso8601(text.to_s)
  rescue Date::Error
    nil
  end

  def parsed_sort
    column, direction = @params[:sort].to_s.match(/\A(\w+?)_(asc|desc)\z/)&.captures
    return if column.nil? || !SORTS.key?(column) || (column == 'total' && !@show_prices)

    [column, direction]
  end

  # ORDER BY one of the SORTS expressions (never text from the request), blanks last.
  def sort_node
    column, direction = parsed_sort || %w[order_date desc]
    expression = Arel.sql(SORTS.fetch(column))
    (direction == 'desc' ? expression.desc : expression.asc).nulls_last
  end
end
