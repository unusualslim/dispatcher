module Samsara
  # The free-text notes drivers see on each Samsara stop (Samsara has no order object; order details go here).
  class StopNotes
    MAX = 2000

    # What to load at the terminal (each product's total across the orders), then the dispatch notes.
    def self.loading(orders, dispatch_notes)
      by_product = orders.flat_map(&:customer_order_products).group_by { |line| line_label(line) }
      load = by_product.map { |label, lines| "#{number(lines.sum { |l| l.quantity.to_i })} #{label}" }
      clip([("Load:\n#{load.join("\n")}" if load.any?), dispatch_notes.presence].compact.join("\n\n"))
    end

    # One stop can carry several orders for the same site.
    def self.delivery(site_orders)
      site = site_orders.first.location
      clip([*site_orders.map { |order| order_block(order) }, *site_lines(site)].join("\n\n"))
    end

    def self.order_block(order)
      products = order.customer_order_products.sort_by(&:id).map { |l| "#{number(l.quantity)} #{line_label(l)}" }
      [order_header(order), *products, order.notes.presence].compact.join("\n")
    end

    def self.order_header(order)
      due = order.required_delivery_date&.strftime('%m/%d')
      header = ["Order #{order.external_order_no.presence || order.id}", order.customer&.name].compact.join(' - ')
      due ? "#{header} (deliver by #{due})" : header
    end

    def self.site_lines(site)
      contacts = site.location_contacts.map { |c| [c.name, c.phone].compact_blank.join(' ') }.compact_blank
      [("Phone: #{site.phone_number}" if site.phone_number.present?),
       ("Contact: #{contacts.join(', ')}" if contacts.any?),
       site.notes.presence].compact
    end

    def self.line_label(line)
      [line.product&.unit_of_measurement, line.product&.name || line.product_name].compact_blank.join(' ')
    end

    def self.number(qty)
      ActiveSupport::NumberHelper.number_to_delimited(qty.to_i)
    end

    def self.clip(text)
      text.to_s.first(MAX)
    end
  end
end
