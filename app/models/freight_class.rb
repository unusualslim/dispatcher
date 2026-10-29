# How much of a bulk product fits on a full truckload (Class A, B, C...). Per-load freight divides the order's
# quantity by this to count loads.
class FreightClass < ApplicationRecord
  has_many :products, dependent: :nullify
  has_many :freight_rules, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.strip.upcase.presence }

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :full_load_quantity, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:code) }

  def label
    "Class #{code} (#{ActiveSupport::NumberHelper.number_to_delimited(full_load_quantity.to_i)} #{unit})"
  end

  # Whole loads needed to carry a quantity: 9,000 gal on an 8,500 gal class is 2 loads.
  def loads_for(quantity)
    (quantity.to_d / full_load_quantity).ceil
  end
end
