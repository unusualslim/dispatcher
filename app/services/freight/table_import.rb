module Freight
  # Replaces a freight table's rows from pasted text (see PastedRows). Mileage: miles, rate (each row = up to those
  # miles; the older from, to, rate with a blank "to" = and over also works). Point to point: origin, destination,
  # rate (blank origin = from anywhere). Flat: rate.
  class TableImport
    include PastedRows

    Result = Struct.new(:imported, :errors, keyword_init: true)

    def initialize(table, text)
      @table = table
      @text = text
      @errors = []
    end

    def call
      rows = pasted_rows(@text).each_with_index.filter_map { |cells, i| build(cells, i + 1) }
      return Result.new(imported: 0, errors: @errors) if @errors.any?
      return Result.new(imported: 0, errors: ['No rows to import.']) if rows.empty?

      FreightTableRate.transaction do
        @table.rates.delete_all
        rows.each(&:save!)
      end
      Result.new(imported: rows.size, errors: [])
    end

    private

    def build(cells, line_no)
      rate = number(cells.last)
      return row_error(line_no, 'needs a rate in the last column') unless rate

      attrs = case @table.lookup_type
              when 'mileage' then mileage(cells, line_no)
              when 'point_to_point' then point_to_point(cells, line_no)
              else {}
              end
      attrs && @table.rates.build(attrs.merge(rate: rate)).tap do |row|
        row_error(line_no, row.errors.full_messages.to_sentence) unless row.valid?
      end
    end

    def mileage(cells, line_no)
      return { miles_to: number(cells[0]) } if cells.size == 2 && number(cells[0])
      return row_error(line_no, 'needs miles, rate') if cells.size < 3

      { miles_from: number(cells[0]) || 0, miles_to: number(cells[1]) }
    end

    def point_to_point(cells, line_no)
      return row_error(line_no, 'needs origin, destination, rate') if cells.size < 3

      origin = cells[0].present? ? find_location(cells[0]) : :any
      destination = find_location(cells[1])
      return row_error(line_no, "origin \"#{cells[0]}\" not found") unless origin
      return row_error(line_no, "destination \"#{cells[1]}\" not found") unless destination

      { origin_location_id: origin == :any ? nil : origin.id, destination_location_id: destination.id }
    end
  end
end
