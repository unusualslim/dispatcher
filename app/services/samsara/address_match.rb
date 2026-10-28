module Samsara
  # Finds the Samsara address that is the same place as an app location, in order of confidence:
  # same street number + street word in the same city, then within GEO_METERS of the location's lat/long,
  # then the same company name (ignoring punctuation and Inc/LLC/Co).
  class AddressMatch
    GEO_METERS = 300

    Result = Struct.new(:address, :how)

    def initialize(addresses)
      @addresses = addresses
    end

    def for(location)
      street_match(location) || geo_match(location) || name_match(location)
    end

    def self.normalize_name(name)
      name.to_s.downcase.gsub('&', ' and ').gsub(/[^a-z0-9 ]/, ' ')
          .gsub(/\b(inc|llc|co|company|the)\b/, ' ').squeeze(' ').strip
    end

    def self.street_key(address)
      m = address.to_s.downcase.match(/\A\s*(\d+)\s+([a-z0-9]+)/)
      m && "#{m[1]} #{m[2]}"
    end

    def self.meters(lat1, lng1, lat2, lng2)
      rad = Math::PI / 180
      x = (lng2 - lng1) * rad * Math.cos((lat1 + lat2) * rad / 2)
      y = (lat2 - lat1) * rad
      Math.sqrt((x * x) + (y * y)) * 6_371_000
    end

    private

    def street_match(location)
      key = self.class.street_key(location.address)
      city = location.city.to_s.downcase.strip
      return if key.nil? || city.blank?

      found = @addresses.find { |a| same_street?(a['formattedAddress'], key, city) }
      found && Result.new(found, 'street address')
    end

    def same_street?(formatted, key, city)
      self.class.street_key(formatted) == key && formatted.to_s.downcase.include?(city)
    end

    def geo_match(location)
      return unless location.latitude && location.longitude

      distance = ->(a) { self.class.meters(location.latitude, location.longitude, a['latitude'], a['longitude']) }
      nearest = located.min_by(&distance)
      nearest && distance.call(nearest) <= GEO_METERS ? Result.new(nearest, 'GPS') : nil
    end

    def located
      @located ||= @addresses.select { |a| a['latitude'] && a['longitude'] }
    end

    def name_match(location)
      name = self.class.normalize_name(location.company_name)
      return if name.blank?

      found = @addresses.find { |a| self.class.normalize_name(a['name']) == name }
      found && Result.new(found, 'name')
    end
  end
end
