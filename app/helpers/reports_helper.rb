module ReportsHelper
  FORMATTERS = {
    currency: ->(h, v) { h.number_to_currency(v) },
    price: ->(h, v) { h.number_to_currency(v, precision: 4) },
    number: ->(h, v) { h.number_with_delimiter(v.to_d.round) },
    decimal: ->(h, v) { h.number_with_delimiter(v.to_d.round(2)) },
    percent: ->(h, v) { h.number_to_percentage(v.to_d * 100, precision: 1) },
    days: ->(h, v) { h.number_with_precision(v, precision: 1) },
    date: ->(_h, v) { v.strftime('%m/%d/%Y') }
  }.freeze

  def report_value(value, format)
    return '' if value.nil?

    FORMATTERS[format]&.call(self, value) || value.to_s
  end

  def report_cell(report, row, column)
    value = report_value(row[column.key], column.format)
    path = report.link_for(row, column)
    path ? link_to(value, path, class: 'text-decoration-none') : value
  end

  def report_numeric?(column)
    FORMATTERS.key?(column.format) && column.format != :date
  end
end
