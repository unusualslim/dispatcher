# Smartank's daily "Inventory" report (FPS_SMARTANK_<yyyyMMdd>_<HHmm>.csv via Power Automate): a few info rows,
# then a header row and one row per tank. Every tank is FPS's; inactive ones and retired "z-" names are created
# ignored. Inventory Time is Eastern. Columns are found by header name.
module TankFeeds
  class Smartank < Base
    FEED = 'smartank'.freeze
    KEY = 'System Tank ID'.freeze
    TIME_FORMATS = ['%m/%d/%Y %H:%M', '%m/%d/%Y %I:%M %p', '%m/%d/%Y %H:%M:%S'].freeze
    DETAILS = { 'location' => 'Location Name', 'address' => 'Address', 'city' => 'City', 'state' => 'State',
                'product' => 'Product', 'capacity' => 'Capacity (gal)', 'cap_limit' => 'Cap Limit (gal)',
                'lat_lon' => 'Lat/Lon', 'serial' => 'Serial # (RTU ID)', 'battery' => 'Bat (%)',
                'volume_alarm' => 'Volume Alarm Status', 'avg_daily_usage_7' => 'Avg. Daily Usage (7)',
                'tank_number' => 'Tank #' }.freeze

    private

    def parse
      table = read_csv
      start = table.index { |values| values.to_a.map { |v| v.to_s.strip }.include?(KEY) }
      raise ArgumentError, "No Smartank header row (#{KEY}) in this file" unless start

      records(table, start).filter_map { |record| readable(row_for(record)) if record[KEY].present? }
    end

    def row_for(record)
      Row.new(external_id: record[KEY].strip, name: record['Tank Name'].to_s.strip,
              read_at: time_in(EASTERN, record['Inventory Time'], *TIME_FORMATS),
              gallons: number(record['Inventory (Net) (gal)']), temperature_f: number(record['Temp (°F)']),
              status: status(record), default_ignored: retired?(record), details: details(record))
    end

    def details(record)
      DETAILS.transform_values { |column| record[column].to_s.strip.presence }
    end

    # Comm. / Sensor problems ("No Recent Update", "Low Battery Alarm"…); blank when both are OK.
    def status(record)
      [record['Comm. Status'], record['Sensor Status']].map { |s| s.to_s.strip }
                                                       .reject { |s| s.blank? || s.casecmp?('OK') }.uniq.join(', ')
    end

    def retired?(record)
      record['Active'].to_s.strip.casecmp?('false') || record['Tank Name'].to_s.strip.downcase.start_with?('z-')
    end
  end
end
