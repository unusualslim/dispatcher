require 'csv'

# Invoice dates (and numbers, salesperson) for PDI orders from a PDI SQL export, since the order API doesn't
# send them. CSV with a header row; columns are found by name: order number, invoice number, invoice date,
# optionally salesperson. Orders are matched on external_order_no and updated in bulk.
class PdiInvoiceDateImportService
  Row = Struct.new(:order_no, :invoice_no, :invoice_date, :salesperson, keyword_init: true)
  Summary = Struct.new(:rows, :matched, :changes, :not_found, :bad_dates, keyword_init: true)
  BATCH = 1000
  VALUES = %i[order_no invoice_date invoice_no salesperson].freeze

  COLUMN_PATTERNS = {
    order_no: /\A(order|ord|od).*(no|num|number|#|id)\z|\Aorder\z/,
    invoice_no: /\A(inv|invoice).*(no|num|number|#|id)\z|\Ainvoice\z/,
    invoice_date: /\A(inv|invoice).*(date|dt)\z|\Abusiness_?date\z/,
    salesperson: /sales/
  }.freeze

  def initialize(path)
    @path = path
  end

  def rows
    @rows ||= begin
      table = CSV.read(@path, headers: true, encoding: 'bom|utf-8')
      columns = find_columns(table.headers)
      table.filter_map { |raw| build_row(raw, columns) }
    end
  end

  # Counts for the preview, without changing anything.
  def summary
    matched = rows.count { |row| existing_orders[row.order_no] }
    Summary.new(rows: rows.size, matched: matched, changes: changes.size, not_found: rows.size - matched,
                bad_dates: @bad_dates.to_i)
  end

  # Returns the number of orders updated.
  def import!
    changes.each_slice(BATCH) { |slice| update_batch!(slice) }
    changes.size
  end

  private

  # Rows whose order is in the app and would change.
  def changes
    @changes ||= rows.select { |row| (order = existing_orders[row.order_no]) && changed?(order, row) }
  end

  def find_columns(headers)
    normalized = headers.map { |header| normalize(header) }
    columns = COLUMN_PATTERNS.transform_values { |pattern| normalized.index { |h| h.match?(pattern) } }
    missing = %i[order_no invoice_date].select { |key| columns[key].nil? }
    raise ArgumentError, "Couldn't find #{missing.join(' and ')} columns in: #{headers.join(', ')}" if missing.any?

    columns
  end

  # "Invoice Date" → "invoice_date"
  def normalize(header)
    header.to_s.strip.downcase.gsub(/[^a-z0-9#]+/, '_').delete_prefix('_').delete_suffix('_')
  end

  def build_row(raw, columns)
    order_no = raw[columns[:order_no]].to_s.strip
    return if order_no.empty? || order_no == 'NULL'

    date = parse_date(raw[columns[:invoice_date]])
    return (@bad_dates = @bad_dates.to_i + 1) && nil unless date

    Row.new(order_no: order_no, invoice_date: date, invoice_no: value(raw, columns[:invoice_no]),
            salesperson: value(raw, columns[:salesperson]))
  end

  def value(raw, index)
    text = raw[index].to_s.strip if index
    text unless text.blank? || text == 'NULL'
  end

  def parse_date(text)
    text = text.to_s.strip
    return if text.empty? || text == 'NULL'

    text.match?(%r{\A\d{1,2}/\d{1,2}/\d{4}}) ? Date.strptime(text, '%m/%d/%Y') : Date.parse(text)
  rescue Date::Error
    nil
  end

  # { order number => { invoice_date:, invoice_no:, salesperson: } } for the file's orders in the app.
  def existing_orders
    @existing_orders ||= rows.map(&:order_no).each_slice(BATCH).with_object({}) do |numbers, found|
      CustomerOrder.where(external_order_no: numbers)
                   .pluck(:external_order_no, :invoice_date, :invoice_no, :salesperson)
                   .each { |no, *details| found[no] = %i[invoice_date invoice_no salesperson].zip(details).to_h }
    end
  end

  def changed?(order, row)
    order[:invoice_date] != row.invoice_date || (row.invoice_no && order[:invoice_no] != row.invoice_no) ||
      (row.salesperson && order[:salesperson] != row.salesperson)
  end

  # One UPDATE … FROM (VALUES …) per batch; invoice # and salesperson only when the export has them.
  def update_batch!(slice)
    values = slice.map do |row|
      ActiveRecord::Base.sanitize_sql_array(['(?, ?::date, ?, ?)', *row.to_h.values_at(*VALUES)])
    end
    CustomerOrder.connection.execute(<<~SQL.squish)
      UPDATE customer_orders o SET invoice_date = v.invoice_date,
        invoice_no = COALESCE(v.invoice_no, o.invoice_no), salesperson = COALESCE(v.salesperson, o.salesperson),
        updated_at = NOW()
      FROM (VALUES #{values.join(', ')}) AS v(order_no, invoice_date, invoice_no, salesperson)
      WHERE o.external_order_no = v.order_no
    SQL
  end
end
