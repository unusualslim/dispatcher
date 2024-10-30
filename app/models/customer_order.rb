class CustomerOrder < ApplicationRecord
  belongs_to :location
  has_many :dispatch_customer_orders
  has_many :dispatches, through: :dispatch_customer_orders
  enum order_status: { New: "New", complete: "Complete", deleted: "Deleted" }
  PRODUCTS = [ "DEF", "Regular", "Plus", "Super", "Eth-Regular", "Eth-Plus", "Eth-Super", "Reg-E10", "Plus-E10", "Super-E10", "ULS", "Dyed ULS" ]
  scope :unassigned_open_orders, -> { where(order_status: 'open').where(dispatch_id: nil) }

  def assign_user_and_create_dispatch
    # Logic to assign user and create a dispatch
    # Example:
    Dispatch.create(customer_order: self, assigned_user: User.first) # Adjust assignment logic as needed
  end

  def unassigned?
    dispatches.empty?
  end
end
