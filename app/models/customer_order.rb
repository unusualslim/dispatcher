class CustomerOrder < ApplicationRecord
  belongs_to :location
  has_many :dispatch_customer_orders
  has_many :dispatches, through: :dispatch_customer_orders
  enum order_status: { New: "New", complete: "Complete", deleted: "Deleted" }
  PRODUCTS = [ "DEF", "Regular", "Plus", "Super", "Eth-Regular", "Eth-Plus", "Eth-Super", "Reg-E10", "Plus-E10", "Super-E10", "ULS", "Dyed ULS" ]
  scope :unassigned_open_orders, -> { where(order_status: 'open').where(dispatch_id: nil) }
end
