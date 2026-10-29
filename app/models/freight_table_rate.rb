# One row of a freight table: a mileage band or an origin → destination pair, and its rate.
class FreightTableRate < ApplicationRecord
  belongs_to :freight_table
  belongs_to :origin_location, class_name: 'Location', optional: true
  belongs_to :destination_location, class_name: 'Location', optional: true

  validates :rate, numericality: true
  validates :destination_location, presence: true, if: -> { freight_table&.lookup_type == 'point_to_point' }
  validates :miles_to, presence: true, if: -> { freight_table&.lookup_type == 'mileage' && miles_from.nil? }
  validate :band_in_order

  def band_label
    if miles_to
      "#{miles_from.to_d.to_s('F').sub(/\.0\z/, '')}–#{miles_to.to_s('F').sub(/\.0\z/, '')} mi"
    else
      "Over #{miles_from.to_d.to_s('F').sub(/\.0\z/, '')} mi"
    end
  end

  private

  def band_in_order
    errors.add(:miles_to, 'must be more than miles from') if miles_from && miles_to && miles_to <= miles_from
  end
end
