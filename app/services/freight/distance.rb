module Freight
  # Road miles estimated from GPS: straight-line distance × a road factor. Only an estimate for mileage tables;
  # the order's freight miles can be typed in to replace it.
  module Distance
    EARTH_RADIUS_MILES = 3958.8
    ROAD_FACTOR = 1.2

    module_function

    def miles(from, to)
      return unless from && to && [from.latitude, from.longitude, to.latitude, to.longitude].all?

      (straight_line(from, to) * ROAD_FACTOR).round(1).to_d
    end

    # Haversine great-circle distance.
    def straight_line(from, to)
      lat1, lon1, lat2, lon2 = [from.latitude, from.longitude, to.latitude, to.longitude].map { |deg| radians(deg) }
      2 * EARTH_RADIUS_MILES * Math.asin(Math.sqrt(haversine_term(lat1, lon1, lat2, lon2)))
    end

    def haversine_term(lat1, lon1, lat2, lon2)
      haversine(lat2 - lat1) + (Math.cos(lat1) * Math.cos(lat2) * haversine(lon2 - lon1))
    end

    def haversine(delta) = Math.sin(delta / 2)**2

    def radians(degrees) = degrees.to_f * Math::PI / 180
  end
end
