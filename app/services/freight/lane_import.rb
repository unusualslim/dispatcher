module Freight
  # Adds or updates lanes from pasted text: origin, destination, miles per line (see PastedRows). All rows are
  # checked before anything is saved.
  class LaneImport
    include PastedRows

    Result = Struct.new(:imported, :errors, keyword_init: true)

    def initialize(text)
      @text = text
      @errors = []
    end

    def call
      lanes = pasted_rows(@text).each_with_index.filter_map { |cells, i| build(cells, i + 1) }
      return Result.new(imported: 0, errors: @errors) if @errors.any?
      return Result.new(imported: 0, errors: ['No rows to import.']) if lanes.empty?

      FreightLane.transaction { lanes.each(&:save!) }
      Result.new(imported: lanes.size, errors: [])
    end

    private

    def build(cells, line_no)
      return row_error(line_no, 'needs origin, destination, miles') if cells.size < 3

      origin, destination = cells.first(2).map { |value| find_location(value) }
      return row_error(line_no, "origin \"#{cells[0]}\" not found") unless origin
      return row_error(line_no, "destination \"#{cells[1]}\" not found") unless destination

      lane(origin, destination, number(cells[2]), line_no)
    end

    def lane(origin, destination, miles, line_no)
      return row_error(line_no, 'needs miles') unless miles&.positive?

      FreightLane.find_or_initialize_by(origin_location: origin, destination_location: destination)
                 .tap { |lane| lane.standard_miles = miles }
    end
  end
end
