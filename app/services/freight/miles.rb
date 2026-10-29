module Freight
  # Miles from an origin to a destination and where they came from: the lane's standard miles, else a GPS
  # estimate. Returns [miles, source] with source :lane, :gps or nil.
  module Miles
    module_function

    def between(origin, destination)
      lane = FreightLane.miles(origin, destination)
      return [lane, :lane] if lane

      gps = Distance.miles(origin, destination)
      gps ? [gps, :gps] : [nil, nil]
    end
  end
end
