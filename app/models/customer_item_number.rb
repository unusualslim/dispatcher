# A customer's own part number for one of our items (printed beside ours on quotes and bills of lading).
class CustomerItemNumber < ApplicationRecord
  belongs_to :customer
  belongs_to :product

  validates :part_number, presence: true
  validates :product_id, uniqueness: { scope: :customer_id }

  # { product_id => part number } for one customer.
  def self.map_for(customer_id)
    return {} if customer_id.blank?

    where(customer_id: customer_id).pluck(:product_id, :part_number).to_h
  end
end
