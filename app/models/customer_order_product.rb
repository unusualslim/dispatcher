class CustomerOrderProduct < ApplicationRecord
  belongs_to :customer_order
  belongs_to :product, optional: true

  validates :quantity, numericality: true, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
