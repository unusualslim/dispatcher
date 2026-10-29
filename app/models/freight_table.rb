# A freight index: the rate looked up by origin → destination (point_to_point), by miles (mileage), or one rate
# (flat). A rule says when to use it; the rule's basis says what the rate means (per gallon, per load, percent...).
class FreightTable < ApplicationRecord
  LOOKUP_TYPES = { 'mileage' => 'Mileage', 'point_to_point' => 'Point to point', 'flat' => 'Flat rate' }.freeze

  has_many :rates, -> { order(:miles_from, :id) }, class_name: 'FreightTableRate', dependent: :delete_all,
                                                   inverse_of: :freight_table
  has_many :freight_rules, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :lookup_type, inclusion: { in: LOOKUP_TYPES.keys }

  scope :ordered, -> { order(:name) }

  def lookup_label = LOOKUP_TYPES[lookup_type]

  # The matching row, or nil. Point to point prefers a row naming the origin over one that leaves it blank;
  # mileage takes the band the miles fall in (from < miles <= to; the first band also takes 0).
  def rate_for(origin_id: nil, destination_id: nil, miles: nil)
    case lookup_type
    when 'flat' then rates.first
    when 'point_to_point' then point_to_point(origin_id, destination_id)
    when 'mileage' then mileage(miles)
    end
  end

  private

  def point_to_point(origin_id, destination_id)
    return unless destination_id

    candidates = rates.select { |r| r.destination_location_id == destination_id }
    candidates.find { |r| r.origin_location_id == origin_id } || candidates.find { |r| r.origin_location_id.nil? }
  end

  def mileage(miles)
    return unless miles

    miles = miles.to_d
    rates.find do |r|
      low = r.miles_from.to_d
      (miles > low || (low.zero? && miles.zero?)) && (r.miles_to.nil? || miles <= r.miles_to)
    end
  end
end
