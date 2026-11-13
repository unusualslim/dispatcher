# Kii's hourly report (KII_<day>_<HH>.csv): a snapshot of each sensor's latest reading, mostly one row per sensor,
# times in UTC without a zone marker. Sensors are ours when Sensor Owner or Customer is Five Points Service; the
# rest (Perry Brothers Oil's Cordele plant, unassigned customers) are created ignored. Kii's Content label is
# unreliable, so the product is set on the app tank.
module TankFeeds
  class Kii < Base
    FEED = 'kii'.freeze
    TIME_FORMATS = ['%m/%d/%Y %I:%M:%S %p', '%m/%d/%Y %H:%M:%S', '%m/%d/%Y %H:%M'].freeze
    DETAILS = { 'customer' => 'Customer', 'sensor_owner' => 'Sensor Owner', 'content' => 'Content',
                'capacity' => 'Capacity (Gal)', 'tank_height_in' => 'Tank Height (In)', 'site_id' => 'Mapping Site ID',
                'tank_number' => 'Mapping Tank ID' }.freeze

    def self.ours?(owner, customer)
      [owner, customer].any? { |name| name.to_s.strip.match?(/\A(five points service|fps)\b/i) }
    end

    private

    def parse
      records(read_csv).filter_map do |record|
        readable(row_for(record)) if record['Sensor Id'].present?
      end
    end

    def row_for(record)
      Row.new(external_id: record['Sensor Id'].strip, name: record['Name'].to_s.strip, **reading(record),
              details: details(record), default_ignored: !self.class.ours?(record['Sensor Owner'], record['Customer']))
    end

    def details(record)
      DETAILS.transform_values { |column| record[column].to_s.strip.delete_suffix('-').presence }
    end

    def reading(record)
      { read_at: time_in('UTC', record['Last Updated Time (UTC)'], *TIME_FORMATS),
        gallons: number(record['Tank Level (Gal)']), water_inches: number(record['Water Level (In)']),
        temperature_f: number(record['Product Temperature (Fahrenheit)']), status: record['Status'].to_s.strip }
    end
  end
end
