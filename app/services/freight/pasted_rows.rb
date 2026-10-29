require 'csv'

module Freight
  # Shared parsing for rows pasted from Excel: comma or tab separated, one row per line, header row skipped;
  # numbers may carry $ , %; locations are app IDs or exact names.
  module PastedRows
    private

    def pasted_rows(text)
      rows = text.lines.map(&:strip).compact_blank.map { |line| split_cells(line) }
      rows.reject { |cells| header?(cells) }
    end

    def split_cells(line)
      CSV.parse_line(line, col_sep: line.include?("\t") ? "\t" : ',').map { |cell| cell.to_s.strip }
    end

    # A header has text and no numbers at all.
    def header?(cells) = cells.none? { |cell| number(cell) } && cells.last.present?

    def number(value)
      cleaned = value.to_s.delete('$,% ')
      BigDecimal(cleaned) if cleaned.match?(/\A-?\d+(\.\d+)?\z/)
    end

    def find_location(value)
      return Location.find_by(id: value) if value.match?(/\A\d+\z/)

      Location.where('LOWER(company_name) = ?', value.downcase).first
    end

    def row_error(line_no, message)
      @errors << "Row #{line_no}: #{message}."
      nil
    end
  end
end
