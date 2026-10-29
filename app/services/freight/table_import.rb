require 'csv'

module Freight
  # Replaces a freight table's rows from pasted text (comma or tab separated, one row per line; a header row is
  # skipped). Mileage: from, to, rate (blank "to" = and over). Point to point: origin, destination, rate, where
  # each location is its app ID or exact name (blank origin = from anywhere). Flat: rate.
  class TableImport
    Result = Struct.new(:imported, :errors, keyword_init: true)

    def initialize(table, text)
      @table = table
      @text = text
      @errors = []
    end

    def call
      rows = parsed_rows.each_with_index.filter_map { |cells, i| build(cells, i + 1) }
      return Result.new(imported: 0, errors: @errors) if @errors.any?
      return Result.new(imported: 0, errors: ['No rows to import.']) if rows.empty?

      FreightTableRate.transaction do
        @table.rates.delete_all
        rows.each(&:save!)
      end
      Result.new(imported: rows.size, errors: [])
    end

    private

    def parsed_rows
      rows = @text.lines.map(&:strip).compact_blank.map { |line| cells(line) }
      rows.reject { |cells| header?(cells) }
    end

    def cells(line)
      CSV.parse_line(line, col_sep: line.include?("\t") ? "\t" : ',').map { |cell| cell.to_s.strip }
    end

    def header?(cells) = cells.last.present? && number(cells.last).nil? && cells.none? { |c| number(c) }

    def build(cells, line_no)
      rate = number(cells.last)
      return error(line_no, 'needs a rate in the last column') unless rate

      attrs = case @table.lookup_type
              when 'mileage' then mileage(cells, line_no)
              when 'point_to_point' then point_to_point(cells, line_no)
              else {}
              end
      attrs && @table.rates.build(attrs.merge(rate: rate)).tap do |row|
        error(line_no, row.errors.full_messages.to_sentence) unless row.valid?
      end
    end

    def mileage(cells, line_no)
      return error(line_no, 'needs from, to, rate') if cells.size < 3

      { miles_from: number(cells[0]) || 0, miles_to: number(cells[1]) }
    end

    def point_to_point(cells, line_no)
      return error(line_no, 'needs origin, destination, rate') if cells.size < 3

      origin = cells[0].present? ? location(cells[0]) : :any
      destination = location(cells[1])
      return error(line_no, "origin \"#{cells[0]}\" not found") unless origin
      return error(line_no, "destination \"#{cells[1]}\" not found") unless destination

      { origin_location_id: origin == :any ? nil : origin.id, destination_location_id: destination.id }
    end

    def location(value)
      return Location.find_by(id: value) if value.match?(/\A\d+\z/)

      Location.where('LOWER(company_name) = ?', value.downcase).first
    end

    def number(value)
      cleaned = value.to_s.delete('$,% ')
      BigDecimal(cleaned) if cleaned.match?(/\A-?\d+(\.\d+)?\z/)
    end

    def error(line_no, message)
      @errors << "Row #{line_no}: #{message}."
      nil
    end
  end
end
