# Filters and sorts the Customers page (CustomersController#index). Params:
#   search (name, PDI ID, phone or email), pdi (linked/unlinked), activity (see ACTIVITY), state, city,
#   inactive, sort ("<column>_asc|desc").
class CustomerListQuery
  KEYS = %w[search pdi activity state city inactive sort].freeze
  ACTIVITY = { 'open' => 'Has open orders', 'recent' => 'Ordered in last 6 months',
               'idle_6' => 'No orders in 6 months', 'idle_12' => 'No orders in 12 months',
               'never' => 'Never ordered' }.freeze

  ORDER_DATE = 'COALESCE(co.order_date, co.created_at)'.freeze
  LAST_ORDER_SQL = "(SELECT MAX(#{ORDER_DATE}) FROM customer_orders co WHERE co.customer_id = customers.id)".freeze
  LOCATIONS_SQL = '(SELECT COUNT(*) FROM customer_locations cl WHERE cl.customer_id = customers.id)'.freeze

  def self.open_orders_sql
    statuses = CustomerOrder::ACTIVE_STATUSES.map { |s| ActiveRecord::Base.connection.quote(s) }.join(', ')
    '(SELECT COUNT(*) FROM customer_orders co ' \
      "WHERE co.customer_id = customers.id AND co.order_status IN (#{statuses}))"
  end

  def initialize(params)
    @params = params
  end

  def relation
    filtered = %i[search by_pdi by_activity by_place by_active].reduce(Customer.all) { |rel, f| send(f, rel) }
    filtered.order(Arel.sql("#{sort_sql} NULLS LAST, customers.name ASC"))
            .select('customers.*', "#{LAST_ORDER_SQL} AS last_order_at",
                    "#{self.class.open_orders_sql} AS open_orders_count")
  end

  private

  def search(rel)
    q = @params[:search].to_s.strip.presence
    return rel unless q

    rel.where('customers.name ILIKE :q OR customers.pdi_customer_id = :exact OR customers.phone ILIKE :q ' \
              'OR customers.email ILIKE :q', q: "%#{q}%", exact: q)
  end

  def by_pdi(rel)
    case @params[:pdi]
    when 'linked' then rel.where.not(pdi_customer_id: nil)
    when 'unlinked' then rel.where(pdi_customer_id: nil)
    else rel
    end
  end

  def by_activity(rel)
    case @params[:activity]
    when 'open' then rel.where("#{self.class.open_orders_sql} > 0")
    when 'recent' then rel.where("#{LAST_ORDER_SQL} >= ?", 6.months.ago)
    when 'idle_6' then rel.where("#{LAST_ORDER_SQL} IS NULL OR #{LAST_ORDER_SQL} < ?", 6.months.ago)
    when 'idle_12' then rel.where("#{LAST_ORDER_SQL} IS NULL OR #{LAST_ORDER_SQL} < ?", 12.months.ago)
    when 'never' then rel.where("#{LAST_ORDER_SQL} IS NULL")
    else rel
    end
  end

  # Customers with a delivery location in the state / city.
  def by_place(rel)
    return rel if @params[:state].blank? && @params[:city].blank?

    rel.where(id: CustomerLocation.where(location_id: places.select(:id)).select(:customer_id))
  end

  def places
    state = @params[:state].presence
    city = @params[:city].to_s.strip.presence
    places = state ? Location.where(state: state) : Location.all
    city ? places.where('locations.city ILIKE ?', "%#{city}%") : places
  end

  def by_active(rel)
    @params[:inactive] == '1' ? rel : rel.active
  end

  def sort_sql
    column, direction = @params[:sort].to_s.match(/\A(\w+?)_(asc|desc)\z/)&.captures
    expression = { 'name' => 'customers.name', 'pdi' => "LPAD(customers.pdi_customer_id, 12, '0')",
                   'last_order' => LAST_ORDER_SQL, 'open_orders' => self.class.open_orders_sql,
                   'locations' => LOCATIONS_SQL }[column] || 'customers.name'
    "#{expression} #{direction == 'desc' ? 'DESC' : 'ASC'}"
  end
end
