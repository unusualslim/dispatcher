module Samsara
  # Sends a dispatch to Samsara as a route for its driver, the way the dispatcher keys them in by hand:
  # home base → origin terminal → each customer stop (order details in the stop notes, see StopNotes) → home base.
  # Only the first stop gets a real time (the dispatch date at the samsara_route_start_time setting); the rest get
  # placeholders that Samsara recomputes from drive time. Re-sending replaces the stops of the route it created,
  # unless the driver has already started it.
  class RoutePush
    PLACEHOLDER_GAP = 30.minutes # arrival times Samsara requires after stop 1; recomputeScheduledTimes replaces them
    SETTINGS = { routeStartingCondition: 'departFirstStop', routeCompletionCondition: 'arriveLastStop' }.freeze

    def self.default_home
      Location.find_by(id: AppSetting.get('samsara_home_location_id'))
    end

    def self.start_time
      AppSetting.get('samsara_route_start_time')
    end

    def initialize(dispatch, client: Client.new)
      @dispatch = dispatch
      @client = client
      @links = Links.new(client)
    end

    # Returns the Samsara route ID.
    def call!
      payload = build
      route_id = existing_route_id
      data = if route_id
               @client.patch("/fleet/routes/#{route_id}", payload)['data']
             else
               @client.post('/fleet/routes', payload)['data']
             end
      @dispatch.update!(samsara_route_id: data['id'], samsara_sent_at: Time.current)
      data['id']
    end

    def build
      driver = @dispatch.driver or raise Error, 'Assign a driver before sending to Samsara.'
      orders = customer_orders
      raise Error, 'Add customer orders before sending to Samsara.' if orders.empty?

      { name: "#{driver.first_name.presence || driver.full_name} - Dispatch #{@dispatch.id}",
        driverId: @links.driver_id!(driver), recomputeScheduledTimes: true, settings: SETTINGS,
        stops: schedule(stops_for(home_for(driver), orders)) }
    end

    def origin = @dispatch.origin_location

    private

    def home_for(driver)
      driver.home_location || self.class.default_home || origin or
        raise Error, 'Set a home base (Admin → Samsara) or an origin terminal first.'
    end

    def customer_orders
      @dispatch.dispatch_customer_order.order(:id)
               .includes(customer_order: [:customer, { location: :location_contacts,
                                                       customer_order_products: :product }])
               .map(&:customer_order).compact.uniq
    end

    def stops_for(home, orders)
      home_id = @links.address_id!(home)
      load_notes = StopNotes.loading(orders, @dispatch.notes)
      [*first_stops(home_id, load_notes), *delivery_stops(orders), { addressId: home_id }]
    end

    # Load notes go on the terminal stop, or on the home base when the driver starts from the terminal.
    def first_stops(home_id, load_notes)
      origin_id = origin && @links.address_id!(origin)
      return [{ addressId: home_id, notes: load_notes }] if origin_id.nil? || origin_id == home_id

      [{ addressId: home_id }, { addressId: origin_id, notes: load_notes }]
    end

    # Orders for the same site in a row become one stop.
    def delivery_stops(orders)
      orders.chunk_while { |a, b| a.location_id == b.location_id }.map do |site_orders|
        { addressId: @links.address_id!(site_orders.first.location), notes: StopNotes.delivery(site_orders) }
      end
    end

    # Departure time on the first stop, placeholder arrival times on the rest (Samsara wants one on the last stop too).
    def schedule(stops)
      stops.first[:scheduledDepartureTime] = start_at.iso8601
      stops.drop(1).each.with_index(1) do |stop, i|
        stop[:scheduledArrivalTime] = (start_at + (PLACEHOLDER_GAP * i)).iso8601
      end
      stops
    end

    def start_at
      @start_at ||= begin
        hour, minute = self.class.start_time.to_s.split(':').map(&:to_i)
        day = @dispatch.dispatch_date || Date.current
        Time.zone.local(day.year, day.month, day.day, hour || 8, minute || 0)
      end
    end

    # The route this dispatch created before, if it's still in Samsara and not yet started.
    def existing_route_id
      return if @dispatch.samsara_route_id.blank?

      route = @client.get("/fleet/routes/#{@dispatch.samsara_route_id}")['data']
      raise Error, 'The driver has already started this route in Samsara, so change it there.' if started?(route)

      route['id']
    rescue Error => e
      raise unless e.message.start_with?('Samsara 404')

      nil
    end

    def started?(route)
      route['actualRouteStartTime'].present?
    end
  end
end
