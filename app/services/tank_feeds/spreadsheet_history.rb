# History from the dispatcher's TankOnHandDaysInv.xlsx, converted to CSV by `rake tanks:spreadsheet_csv`
# (columns tab, site, date, fill_limit, gallons, day_load, night_load). Each tab is a feed tank; each typed
# 6AM inventory is a reading at 6:00 AM Eastern. Loads are kept in the CSV for delivery history (phase 3).
module TankFeeds
  class SpreadsheetHistory < Base
    FEED = 'spreadsheet'.freeze
    REQUIRED = %w[tab date gallons].freeze

    private

    def parse
      records(table).filter_map { |record| readable(row_for(record)) if record['tab'].present? }
    end

    # The CSV with a lower-case header row.
    def table
      csv = read_csv
      csv[0] = csv.first.to_a.map { |h| h.to_s.strip.downcase }
      raise ArgumentError, 'Expected columns tab, site, date, gallons' unless (REQUIRED - csv.first).empty?

      csv
    end

    def row_for(record)
      Row.new(external_id: record['tab'].strip.upcase, name: record['site'].to_s.strip,
              read_at: six_am(record['date']), gallons: number(record['gallons']),
              details: { 'fill_limit' => record['fill_limit'].to_s.strip }, default_ignored: false)
    end

    def six_am(text)
      date = Date.iso8601(text.to_s.strip)
      Time.find_zone!(EASTERN).local(date.year, date.month, date.day, 6)
    rescue ArgumentError
      nil
    end
  end
end
