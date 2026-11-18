# One cost a vendor charges for an item: its part number, what it's for (a package, a quantity break), the cost
# and when it took effect. Several per vendor and item.
class VendorItemPrice < ApplicationRecord
  belongs_to :product_vendor

  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }
  validates :min_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, -> { order(:min_quantity, :id) }
end
