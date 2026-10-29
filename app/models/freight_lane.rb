# Standard miles from an origin (terminal / warehouse) to a destination. Orders price mileage freight off these
# unless miles are typed on the order; per-dispatch carrier freight uses them to find the farthest stop.
class FreightLane < ApplicationRecord
  belongs_to :origin_location, class_name: 'Location'
  belongs_to :destination_location, class_name: 'Location'

  validates :standard_miles, numericality: { greater_than: 0 }
  validates :destination_location_id, uniqueness: { scope: :origin_location_id }

  def self.miles(origin, destination)
    return unless origin && destination

    where(origin_location_id: origin.id, destination_location_id: destination.id).pick(:standard_miles)
  end
end
