module Mrp
  # Firm supply and demand for the planned products, as dated Events per product ID:
  #   + open purchase order lines on their expected delivery date
  #   + open production orders' output on their due date
  #   - open production orders' components on their production date
  #   - open customer order lines on their delivery date (undated: order date + the customer's lead time)
  # Anything dated before today counts today and is flagged; anything after the horizon is left out.
  # Each event carries its warehouse (location_id); dropship order lines are left out (no stock moves).
  class Events
    OPEN_PO_STATUSES = %w[draft pending_approval approved submitted].freeze
    # Stock is still on hand from Open Order through picking; quotes and pending orders don't consume it,
    # and by Released for Billing PDI has relieved it.
    DEMAND_STATUSES = (CustomerOrder::ACTIVE_STATUSES - ['Quote', 'Pending', 'Released for Billing']).freeze

    include Rails.application.routes.url_helpers

    def initialize(product_ids, today:, horizon_end:)
      @ids = product_ids
      @today = today
      @horizon_end = horizon_end
      @events = Hash.new { |hash, id| hash[id] = [] }
    end

    def load
      purchases
      productions
      components
      customer_orders
      @events
    end

    private

    def purchases
      PurchaseOrderLineItem.joins(:purchase_order).includes(purchase_order: :vendor)
                           .where(product_id: @ids, purchase_orders: { status: OPEN_PO_STATUSES })
                           .find_each { |line| add(line.product_id, **purchase_event(line)) }
    end

    def purchase_event(line)
      po = line.purchase_order
      date = po.expected_delivery_date || po.created_at.to_date
      { date: date, qty: line.quantity, kind: :purchase, label: "PO #{po.display_number} · #{po.vendor&.name}",
        path: purchase_order_path(po), flags: [(:late if date < @today), (:draft if po.status == 'draft')].compact,
        location_id: po.location_id }
    end

    def productions
      open_production_orders.where(product_id: @ids).find_each do |order|
        add(order.product_id, date: order.due_date || order.production_date || @today, qty: order.qty_to_make,
                              kind: :production, label: "Production #{order.number}",
                              path: production_order_path(order), location_id: order.location_id)
      end
    end

    def components
      ProductionOrderComponent.joins(:production_order).merge(open_production_orders).includes(:production_order)
                              .where(product_id: @ids)
                              .find_each { |component| add(component.product_id, **component_event(component)) }
    end

    def component_event(component)
      order = component.production_order
      { date: order.production_date || order.due_date || @today, qty: -component.quantity.to_d, kind: :component,
        label: "Production #{order.number} uses", path: production_order_path(order), ref: component.id,
        location_id: order.location_id }
    end

    def open_production_orders
      ProductionOrder.where(status: ProductionOrder::OPEN_STATUSES, voided_at: nil)
    end

    def customer_orders
      CustomerOrderProduct.joins(:customer_order).includes(customer_order: :customer)
                          .where(product_id: @ids, customer_orders: { order_status: DEMAND_STATUSES })
                          .where('customer_order_products.warehouse IS NULL OR ' \
                                 'customer_order_products.warehouse NOT IN (?)', CustomerOrderProduct::DROPSHIP_SITES)
                          .find_each { |line| add(line.product_id, **order_event(line)) }
    end

    def order_event(line)
      order = line.customer_order
      date = delivery_date(order)
      { date: date, qty: -line.quantity.to_d, kind: :order, label: order_label(order),
        path: customer_order_path(order), flags: date < @today ? [:overdue] : [],
        location_id: line.location_id || order.ship_from_location_id }
    end

    def delivery_date(order)
      return order.required_delivery_date if order.required_delivery_date

      ordered = (order.order_date || order.created_at).to_date
      ordered + (order.customer&.lead_time_days || AppSetting.mrp_days('mrp_customer_lead_days'))
    end

    def order_label(order)
      ["Order #{order.external_order_no || order.id}", order.customer&.name].compact.join(' · ')
    end

    def add(product_id, date:, qty:, flags: [], **attrs)
      return if qty.to_d.zero? || date > @horizon_end

      @events[product_id] << Event.new(date: [date, @today].max, qty: qty.to_d, flags: flags,
                                       original_date: (date if date < @today), **attrs)
    end
  end
end
