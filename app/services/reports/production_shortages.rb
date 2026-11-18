module Reports
  # Open production orders' missing components: for each order (soonest due first) the components the warehouse
  # can't cover after earlier orders take theirs, how short, and what's coming in on open POs.
  class ProductionShortages < Base
    OPEN = %w[created in_progress].freeze
    OPEN_PO = %w[approved submitted].freeze

    report title: 'Production shortages', area: :production,
           description: 'Components open production orders are missing, soonest due first, with quantity short ' \
                        'and quantity on open POs.',
           filters: %i[location_id category]

    def columns
      [column(:order, 'Production order'), column(:due, 'Due', :date), column(:made, 'Making'),
       column(:quantity, 'Qty to make', :decimal), column(:component, 'Component'),
       column(:description, 'Description'), column(:warehouse, 'Warehouse'), column(:needed, 'Needed', :decimal),
       column(:available, 'Available', :decimal), column(:short, 'Short', :decimal, total: true),
       column(:on_order, 'On open POs', :decimal), column(:substitutes, 'Substitutes on hand')]
    end

    def rows
      @rows ||= begin
        left = Hash.new { |h, key| h[key] = stock.fetch(key, 0.to_d) }
        orders.flat_map { |order| order_rows(order, left) }
      end
    end

    def link_for(row, column)
      Rails.application.routes.url_helpers.production_order_path(row[:order_id]) if column.key == :order
    end

    private

    def orders
      components = { production_order_components: { product: :product_substitutes } }
      scope = ProductionOrder.where(status: OPEN).includes(:product, :location, components)
      scope = scope.where(location_id: filters[:location_id]) if filters[:location_id]
      scope = scope.joins(:product).where(products: { category: filters[:category] }) if filters[:category]
      scope.sort_by { |o| [o.due_date || Date.new(2100), o.id] }
    end

    def order_rows(order, left)
      order.production_order_components.select(&:product_id).filter_map do |component|
        key = [component.product_id, order.location_id]
        needed = component.quantity.to_d
        available = left[key]
        left[key] = [available - needed, 0].max
        short_row(order, component, needed, available) if needed > available
      end
    end

    def short_row(order, component, needed, available)
      { order_id: order.id, order: order.number, due: order.due_date, made: order.product&.name || order.item,
        quantity: order.qty_to_make&.to_d, component: component.product_id,
        description: component.product&.name || component.description,
        warehouse: order.location&.pdi_site_code.presence || order.location&.company_name, needed: needed,
        available: available, short: needed - available, on_order: on_order.fetch(component.product_id, 0).to_d,
        substitutes: substitutes_on_hand(component.product, order.location_id) }
    end

    # "9001: 40 (×1)" for each approved substitute with stock at the order's warehouse.
    def substitutes_on_hand(product, location_id)
      product.product_substitutes.filter_map do |sub|
        qty = stock.fetch([sub.substitute_id, location_id], 0.to_d)
        "#{sub.substitute_id}: #{qty.round(3).to_s('F').delete_suffix('.0')}" if qty.positive?
      end.join(', ').presence
    end

    # { [product_id, location_id] => quantity on hand }
    def stock
      @stock ||= LocationProduct.group(:product_id, :location_id).sum(:quantity).transform_values(&:to_d)
    end

    def on_order
      @on_order ||= PurchaseOrderLineItem.joins(:purchase_order)
                                         .where(purchase_orders: { status: OPEN_PO, voided_at: nil })
                                         .group(:product_id).sum(:quantity)
    end
  end
end
