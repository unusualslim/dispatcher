# Green / yellow / red for each component of open production orders, from the same dated supply and
# demand MRP uses (Mrp::Events) at the production order's warehouse, taking earlier needs first:
#   green  - stock on hand now covers this and every earlier need
#   yellow - covered only by a PO or production run arriving by then (or a late PO), leaves stock below
#            safety stock (at the product's main warehouse), the component isn't linked to a product, or
#            the production order has no warehouse
#   red    - short even with what's on order
# An order's readiness is its worst component. Orders past in_progress have used their materials.
class MaterialReadiness
  OPEN_STATUSES = %w[created in_progress].freeze
  LEVELS = %i[green yellow red].freeze

  Status = Struct.new(:level, :reason)

  def initialize(production_orders)
    @orders = production_orders.select { |order| OPEN_STATUSES.include?(order.status) }
    @statuses = {}
    compute if @orders.any?
  end

  def component(component)
    @statuses[component.id]
  end

  def order(order)
    @statuses.values_at(*component_ids[order.id]).compact.max_by { |status| LEVELS.index(status.level) }
  end

  private

  def component_ids
    @component_ids ||= ProductionOrderComponent.where(production_order_id: @orders.map(&:id))
                                               .pluck(:production_order_id, :id).group_by(&:first)
                                               .transform_values { |rows| rows.map(&:last) }
  end

  def compute
    components = ProductionOrderComponent.where(production_order_id: @orders.map(&:id)).to_a
    components.reject(&:product_id).each { |c| @statuses[c.id] = Status.new(:yellow, 'Not linked to a product') }
    walk_products(components.filter_map(&:product_id).uniq)
  end

  def walk_products(ids)
    events = Mrp::Events.new(ids, today: Date.current, horizon_end: Date.current + 10.years).load
    @stock = load_stock(ids)
    Product.where(id: ids).find_each do |product|
      events[product.id].group_by(&:location_id).each { |location_id, list| walk_at(product, location_id, list) }
    end
  end

  # [product ID, location ID] → quantity on hand there.
  def load_stock(ids)
    LocationProduct.where(product_id: ids).pluck(:product_id, :location_id, :quantity)
                   .to_h { |product_id, location_id, qty| [[product_id, location_id], qty.to_d] }
  end

  def walk_at(product, location_id, events)
    return no_warehouse(events) unless location_id

    @home = main_location(product.id) == location_id
    walk(product, events, @stock[[product.id, location_id]] || 0)
  end

  def no_warehouse(events)
    status = Status.new(:yellow, 'No warehouse set on this production order')
    events.select(&:ref).each { |event| @statuses[event.ref] = status }
  end

  def main_location(product_id)
    @stock.select { |(id, _), _| id == product_id }.max_by { |_, qty| qty }&.first&.last
  end

  # Supply first on a day; demand in date order, so earlier needs take the stock first.
  def walk(product, events, on_hand)
    @tally = { on_hand: on_hand.to_d, supply: 0.to_d, demand: 0.to_d, late: false }
    events.sort_by { |e| [e.date, e.supply? ? 0 : 1, e.ref.to_i] }.each do |event|
      event.supply? ? add_supply(event) : add_demand(product, event)
    end
  end

  def add_demand(product, event)
    @tally[:demand] -= event.qty
    @statuses[event.ref] = status(product, event.date) if event.ref
  end

  def add_supply(event)
    @tally[:supply] += event.qty
    @tally[:late] ||= event.flags.include?(:late)
  end

  def status(product, date)
    on_hand, supply, demand = @tally.values_at(:on_hand, :supply, :demand)
    short = demand - on_hand - supply
    return Status.new(:red, "Short #{fmt(short)} by #{date.strftime('%b %-d')}, even with orders") if short.positive?
    return Status.new(:yellow, incoming_reason) if demand > on_hand
    return Status.new(:yellow, 'In stock, but leaves less than safety stock') if below_safety?(product)

    Status.new(:green, "In stock: #{fmt(on_hand)} on hand covers this and earlier needs")
  end

  def below_safety?(product)
    safety = @home ? product.safety_stock.to_d : 0
    safety.positive? && @tally[:on_hand] - @tally[:demand] < safety
  end

  def incoming_reason
    @tally[:late] ? 'Depends on a purchase order that is already late' : 'Depends on supply arriving in time'
  end

  def fmt(qty)
    ActiveSupport::NumberHelper.number_to_delimited(qty.round(1).to_s.sub(/\.0\z/, ''))
  end
end
