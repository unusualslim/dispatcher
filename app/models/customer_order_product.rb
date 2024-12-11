class CustomerOrderProduct < ApplicationRecord
  belongs_to :customer_order
  belongs_to :product

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
end
