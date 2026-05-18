class CustomerOrder < ApplicationRecord
  belongs_to :location
  belongs_to :customer, optional: true

  has_many :dispatch_customer_orders, dependent: :destroy
  has_many :dispatches, through: :dispatch_customer_orders

  has_many :customer_order_products, dependent: :destroy
  has_many :products, through: :customer_order_products
  has_and_belongs_to_many :things

  accepts_nested_attributes_for :customer_order_products, allow_destroy: true

  attribute :freight_only, :boolean, default: false
  enum order_status: { New: "New", complete: "Complete", deleted: "Deleted", on_hold: "On Hold" }

  PRODUCTS = [ "DEF", "Regular", "Plus", "Super", "Eth-Regular", "Eth-Plus", "Eth-Super", "Reg-E10", "Plus-E10", "Super-E10", "ULS", "Dyed ULS" ]
  scope :unassigned_open_orders, -> { where(order_status: 'open').where(dispatch_id: nil) }

  def assign_user_and_create_dispatch
    Dispatch.create(customer_order: self, assigned_user: User.first) # Adjust assignment logic as needed
  end

  def unassigned?
    dispatches.empty?
  end

  def total_weight
    products.sum(&:weight)
  end


end
