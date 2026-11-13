# The site 0002 tank email (FPS_TANKS_0002_<yyyyMMdd>_<HHmm>.txt via Power Automate): lines "<tank> <n> Gallons"
# with no date inside, so the reading time comes from the file name (Eastern) or is given on upload. Each named
# line is a feed tank; DI Water is created ignored, and nameless "0 Gallons" lines are skipped. Map the Bulk DEF
# tanks (Tank 1-6, T-8 500 K, P-1..P-3, Tank 11-16) to one app tank to get the plant's total.
module TankFeeds
  class Plant0002 < Base
    FEED = 'plant_0002'.freeze
    LINE = /\A(?<name>.*?)\s*(?<gallons>-?[\d,]+(?:\.\d+)?)\s+gallons\s*\z/i
    NAME_STAMP = /(\d{8})[_-](\d{4})/
    NO_TIME = 'No reading time: name the file FPS_TANKS_0002_yyyyMMdd_HHmm.txt or enter the time'.freeze

    # FPS_TANKS_0002_20261111_0600.txt → 2026-11-11 06:00 Eastern
    def self.time_from_name(filename)
      match = File.basename(filename.to_s).match(NAME_STAMP)
      Time.find_zone!(EASTERN).strptime("#{match[1]} #{match[2]}", '%Y%m%d %H%M') if match
    rescue ArgumentError
      nil
    end

    def initialize(path, read_at: nil, file_name: nil, **)
      super
      @read_at = read_at || self.class.time_from_name(file_name || path)
    end

    private

    def parse
      raise ArgumentError, NO_TIME unless @read_at

      File.read(@path, mode: 'rb').force_encoding('UTF-8').scrub.each_line.filter_map { |line| row_for(line) }
    end

    def row_for(line)
      match = line.strip.match(LINE)
      return unless match && match[:name].present?

      name = match[:name].squish
      Row.new(external_id: name, name: name, read_at: @read_at, gallons: number(match[:gallons]),
              default_ignored: name.match?(/\bDI\s*water\b/i), details: {})
    end
  end
end
