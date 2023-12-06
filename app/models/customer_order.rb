class CustomerOrder < ApplicationRecord
  belongs_to :location
  has_many :dispatch_customer_orders
  has_many :dispatches, through: :dispatch_customer_orders
  enum order_status: { New: "New", complete: "Complete", deleted: "Deleted" }
  enum product: { def: "def" }
end
