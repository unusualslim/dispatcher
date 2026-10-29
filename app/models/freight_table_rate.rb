# One row of a freight table: a mileage band or an origin → destination pair, and its rate.
class FreightTableRate < ApplicationRecord
  belongs_to :freight_table
  belongs_to :origin_location, class_name: 'Location', optional: true
  belongs_to :destination_location, class_name: 'Location', optional: true

  validates :rate, numericality: true
  validates :destination_location, presence: true, if: -> { freight_table&.lookup_type == 'point_to_point' }
  validates :miles_to, presence: true, if: -> { freight_table&.lookup_type == 'mileage' && miles_from.nil? }
  validate :band_in_order

  # "Up to 20 mi", or "Over 300 mi" for an open-ended last row.
  def band_label
    miles_to ? "Up to #{trim(miles_to)} mi" : "Over #{trim(miles_from.to_d)} mi"
  end

  private

  def trim(number) = number.to_s('F').sub(/\.0\z/, '')

  def band_in_order
    errors.add(:miles_to, 'must be more than miles from') if miles_from && miles_to && miles_to <= miles_from
  end
end
