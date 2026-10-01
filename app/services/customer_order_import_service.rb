require 'roo'
require 'roo-xls'

class CustomerOrderImportService
  Result     = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true)
  PreviewRow = Struct.new(:external_order_no, :customer_name, :order_date, :odor_status, :line_items_count, :action, keyword_init: true)

  # Normalize PDI status strings so capitalization variants all resolve to the correct enum key.
  CANONICAL_STATUS = CustomerOrder.order_statuses.invert
                                  .transform_keys(&:downcase)
                                  .merge("open" => "open_order").freeze

  def self.call(file_path)
    new(file_path).run
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def preview
    parse_orders.map do |order_data|
      external_order_no = order_data[:external_order_no]
      existing = CustomerOrder.find_by(external_order_no: external_order_no)
      PreviewRow.new(
        external_order_no: external_order_no,
        customer_name:     order_data[:customer_name],
        order_date:        order_data[:order_date],
        odor_status:       order_data[:odor_status],
        line_items_count:  order_data[:line_items]&.size || 0,
        action:            existing ? :update : :create
      )
    end
  end

  def run
    result = Result.new(created: 0, updated: 0, skipped: 0, errors: [])

    parse_orders.each do |order_data|
      import_order(order_data, result)
    rescue => e
      result.errors << "#{order_data[:external_order_no]}: #{e.message}"
    end

    result
  end

  private

  # Parses the PDI "Order Detail" XLS export. Each order spans multiple labeled
  # rows ("Order No:", "Customer:", etc.) followed by numeric product line rows.
  # "Load Information" blocks repeat the same products at the load level — we
  # skip those to avoid duplicates.
  def parse_orders
    sheet = Roo::Excel.new(@file_path)
    sheet.default_sheet = sheet.sheets.first

    orders = []
    current_order = nil
    in_load_section = false

    (sheet.first_row..sheet.last_row).each do |i|
      row = sheet.row(i)
      next if row.compact.empty?

      label = row[0].to_s.strip

      case label
      when "Order No:"
        orders << current_order if current_order
        current_order = {
          external_order_no: row[2].to_s.strip,
          business_date:     to_date(row[8]),
          odor_status:       row[14].to_s.strip,
          carrier:           row[19].to_s.strip.presence,
          line_items:        [],
        }
        in_load_section = false

      when "Customer:"
        next unless current_order
        current_order[:customer_name] = row[2].to_s.strip.sub(/\A\d+\s*-\s*/, '')
        current_order[:order_date]    = to_date(row[8])
        current_order[:invoice_no]    = row[14].to_s.strip.presence

      when "Location / Site:"
        next unless current_order
        current_order[:location_name] = row[2].to_s.strip.presence
        current_order[:delivery_date] = to_date(row[8])

      when "Salesperson:"
        next unless current_order
        current_order[:salesperson]  = row[2].to_s.strip.presence
        current_order[:invoice_date] = to_date(row[8])

      when "Load Information"
        # Load-level block repeats order products; skip to avoid duplicates
        in_load_section = true

      else
        next unless current_order
        next if in_load_section
        next unless row[0].is_a?(Numeric) && row[1].is_a?(String)
        current_order[:line_items] << {
          product_code: row[1].to_s.strip,
          ordered_qty:  row[5].to_f.round,
          unit_price:   row[14].to_d,
        }
      end
    end

    orders << current_order if current_order
    orders.compact.select { |o| o[:external_order_no].present? }
  end

  def import_order(order_data, result)
    external_order_no = order_data[:external_order_no]
    return if external_order_no.blank?

    existing = CustomerOrder.find_by(external_order_no: external_order_no)

    customer = find_or_create_customer(order_data[:customer_name])
    location = find_or_create_location(order_data[:location_name])
    status   = CANONICAL_STATUS[order_data[:odor_status].to_s.downcase] || "open_order"

    attrs = {
      external_order_no:      external_order_no,
      order_date:             order_data[:order_date],
      required_delivery_date: order_data[:delivery_date],
      invoice_no:             order_data[:invoice_no],
      invoice_date:           order_data[:invoice_date],
      odor_status:            order_data[:odor_status],
      order_status:           status,
      carrier:                order_data[:carrier],
      salesperson:            order_data[:salesperson],
      customer:               customer,
      location:               location,
    }

    if existing
      existing.update!(attrs)
      sync_line_items(existing, order_data[:line_items])
      existing.sync_approximate_amount
      result.updated += 1
    else
      order = CustomerOrder.create!(attrs)
      sync_line_items(order, order_data[:line_items])
      order.sync_approximate_amount
      result.created += 1
    end
  end

  def sync_line_items(order, line_items)
    return if line_items.blank?

    order.customer_order_products.destroy_all

    line_items.each do |item|
      product   = Product.find_by(id: item[:product_code])
      item_type = (product && !product.is_raw_material?) ? 'production' : 'buy'
      order.customer_order_products.create!(
        product_name: item[:product_code],
        product_id:   product&.id,
        item_type:    item_type,
        quantity:     item[:ordered_qty],
        price:        item[:unit_price],
      )
    end
  end

  def find_or_create_customer(name)
    return nil if name.blank?
    Customer.find_or_create_by(name: name) do |c|
      c.preferred_contact_method = 'no preference'
    end
  end

  def find_or_create_location(name)
    return Location.first! if name.blank?
    Location.find_or_create_by(company_name: name) do |l|
      l.location_category_id = 2
    end
  end

  def to_date(val)
    return nil if val.nil?
    val.respond_to?(:to_date) ? val.to_date : Date.parse(val.to_s)
  rescue
    nil
  end
end
