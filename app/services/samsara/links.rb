module Samsara
  # Resolves the Samsara records a route needs, remembering each link on the app record:
  # users.samsara_driver_id (matched by full name) and locations.samsara_address_id (matched with
  # AddressMatch, else created in Samsara from the location's address).
  class Links
    GEOFENCE_METERS = 250 # Samsara's default circle, as on the dispatcher's own addresses

    def initialize(client = Client.new)
      @client = client
    end

    def driver_id!(user)
      return user.samsara_driver_id if user.samsara_driver_id.present?

      name = AddressMatch.normalize_name(user.full_name)
      found = drivers.find { |d| AddressMatch.normalize_name(d['name']) == name }
      raise Error, "#{user.full_name} isn't linked to a Samsara driver. Link them on Admin → Samsara." unless found

      user.update!(samsara_driver_id: found['id'])
      found['id']
    end

    def address_id!(location)
      return location.samsara_address_id if location.samsara_address_id.present?

      found = AddressMatch.new(addresses).for(location)&.address || create_address(location)
      location.update!(samsara_address_id: found['id'])
      found['id']
    end

    def drivers
      @drivers ||= @client.drivers
    end

    def addresses
      @addresses ||= @client.addresses
    end

    private

    def create_address(location)
      if location.address.blank? && !geocoded?(location)
        raise Error, "#{location.company_name} has no street address or GPS position to create a Samsara address from."
      end

      created = @client.post('/addresses', address_body(location))['data']
      addresses << created
      created
    end

    def address_body(location)
      body = { name: location.company_name.to_s.strip.first(255), formattedAddress: formatted_address(location),
               geofence: { circle: { radiusMeters: GEOFENCE_METERS } } }
      geocoded?(location) ? body.merge(latitude: location.latitude, longitude: location.longitude) : body
    end

    def formatted_address(location)
      [location.address, location.city, [location.state, location.zip].compact_blank.join(' ')]
        .map { |part| part.to_s.strip }.compact_blank.join(', ')
    end

    def geocoded?(location)
      location.latitude.present? && location.longitude.present?
    end
  end
end
