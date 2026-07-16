require 'pdf-reader'
require 'open3'

class CustomerOrderImportService
  Result     = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true)
  PreviewRow = Struct.new(:external_order_no, :customer_name, :order_date, :odor_status, :line_items_count, :action, keyword_init: true)

  # Maps ODOR order status to CustomerOrder order_status enum key
  STATUS_MAP = {
    'Billed'              => :complete,
    'Cancelled As Order'  => :deleted,
    'Cancelled As Quote'  => :deleted,
  }.freeze

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

  def parse_orders
    full_text = extract_text

    # Split on newlines immediately before each indented "Order No:" line.
    # Using \n in the pattern (rather than a lookahead alone) prevents the
    # lookahead from matching at every leading-space position on the same line.
    blocks = full_text.split(/\n(?=[ \t]{2,}Order No:\s+OD-)/)
    blocks.shift # discard text before the first order (page 1 report settings)

    blocks.filter_map { |block| parse_order_block(block) }
  end

  # Use pdftotext (poppler) when available — it handles character ordering and
  # font encoding far better than pdf-reader, which occasionally drops or
  # misorders the first character of a word.  Falls back to pdf-reader if
  # pdftotext is not installed.
  def extract_text
    stdout, status = Open3.capture2('pdftotext', '-layout', @file_path, '-')
    return stdout if status.success?
    pdf_reader_text
  rescue Errno::ENOENT
    pdf_reader_text
  end

  def pdf_reader_text
    PDF::Reader.new(@file_path).pages.map(&:text).join("\n")
  end

  def parse_order_block(block)
    order = {}

    if m = block.match(/Order No:\s+(OD-\S+)/)
      order[:external_order_no] = m[1]
    else
      return nil
    end

    if m = block.match(/Business Date:\s+(\d{2}\/\d{2}\/\d{4})/)
      order[:business_date] = parse_date(m[1])
    end

    # Status ends at 3+ spaces or "Carrier:" or end of line
    if m = block.match(/Status:\s+(\S.*?)(?=\s{3,}|Carrier:|\n)/)
      order[:odor_status] = m[1].strip
    end

    # Customer: "NNNN - Customer Name   Order Date/Time:"
    if m = block.match(/Customer:\s+\d+\s+-\s+(.+?)(?=\s{3,}|Order Date)/)
      order[:customer_name] = m[1].strip
    end

    if m = block.match(/Order Date\/Time:\s+(\d{2}\/\d{2}\/\d{4})/)
      order[:order_date] = parse_date(m[1])
    end

    # Location/Site may have no space after the colon; restrict to the current
    # line ([ \t]* not \s*) so a blank location doesn't capture the next line.
    if m = block.match(/Location \/ Site:[ \t]*(\S[^\n]*?)(?=[ \t]{3,}|Delivery Date|\n|$)/)
      order[:location_name] = m[1].strip
    end

    if m = block.match(/Delivery Date\/Time:\s+(\d{2}\/\d{2}\/\d{4})/)
      order[:delivery_date] = parse_date(m[1])
    end

    if m = block.match(/Invoice No\s+(INV-\S+)/)
      order[:invoice_no] = m[1].strip
    end

    # Carrier immediately follows "Carrier:" with no space (e.g. "Carrier:FPS PRICING")
    if m = block.match(/Carrier:\s*(\S.*?)(?=\s{3,}|\n)/)
      order[:carrier] = m[1].strip
    end

    if m = block.match(/Invoice Date:\s+(\d{2}\/\d{2}\/\d{4})/)
      order[:invoice_date] = parse_date(m[1])
    end

    if m = block.match(/Salesperson:\s+(\S.*?)(?=\s{3,}|Invoice Date|\n)/)
      order[:salesperson] = m[1].strip
    end

    # Parse product lines
    order[:line_items] = []
    block.each_line do |line|
      item = parse_product_line(line)
      order[:line_items] << item if item
    end

    order
  end

  # Product lines look like:
  #   PRODUCTCODE / PACKAGE   N - WAREHOUSE   QTY QTY QTY PRICE DISC EXTENDED TAXES TOTAL
  # Credit memo quantities have a trailing dash: 1.00-
  def parse_product_line(line)
    stripped = line.strip
    return nil if stripped.empty?
    return nil if stripped =~ /Order Totals/
    # Product code is ALL-UPPERCASE letters and/or digits, no lowercase
    return nil unless stripped =~ /\A[A-Z0-9]+\s+\/\s+\S/

    # Split on 2+ spaces to separate the whitespace-padded columns
    parts = stripped.split(/\s{2,}/)
    return nil unless parts.length >= 9

    product_and_package = parts[0].split(' / ', 2)
    return nil unless product_and_package.length == 2

    {
      product_code: product_and_package[0],
      package:      product_and_package[1],
      warehouse:    parts[1],
      ordered_qty:  parse_qty(parts[2]),
      unit_price:   parse_decimal(parts[5]),
    }
  end

  def import_order(order_data, result)
    external_order_no = order_data[:external_order_no]
    return if external_order_no.blank?

    existing = CustomerOrder.find_by(external_order_no: external_order_no)

    customer  = find_or_create_customer(order_data[:customer_name])
    location  = find_or_create_location(order_data[:location_name])
    status    = STATUS_MAP.fetch(order_data[:odor_status], :New)

    attrs = {
      external_order_no:       external_order_no,
      order_date:              order_data[:order_date],
      required_delivery_date:  order_data[:delivery_date],
      invoice_no:              order_data[:invoice_no],
      invoice_date:            order_data[:invoice_date],
      odor_status:             order_data[:odor_status],
      order_status:            status,
      carrier:                 order_data[:carrier],
      salesperson:             order_data[:salesperson],
      customer:                customer,
      location:                location,
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

    # Replace all line items on each import so data stays in sync
    order.customer_order_products.destroy_all

    line_items.each do |item|
      product = Product.find_by(id: item[:product_code])
      order.customer_order_products.create!(
        product_name: "#{item[:product_code]} / #{item[:package]}",
        product_id:   product&.id,
        warehouse:    item[:warehouse],
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

    # Location category 2 = customer delivery site (destination)
    Location.find_or_create_by(company_name: name) do |l|
      l.location_category_id = 2
    end
  end

  def parse_date(str)
    Date.strptime(str, '%m/%d/%Y')
  rescue
    nil
  end

  # Parse quantity: "924.00" → 924, "1.00-" → -1
  def parse_qty(str)
    str = str.to_s.strip
    negative = str.end_with?('-')
    value = str.delete('-,').to_f
    result = negative ? -value : value
    result.round
  end

  # Parse decimal: "18.4600" → 18.46, "65.00-" → -65.00
  def parse_decimal(str)
    str = str.to_s.strip
    negative = str.end_with?('-')
    value = str.delete('-,').to_d
    negative ? -value : value
  end
end
