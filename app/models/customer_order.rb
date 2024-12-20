class CustomerOrder < ApplicationRecord
  belongs_to :location
  belongs_to :customer, optional: true
  has_many :dispatch_customer_orders
  has_many :dispatches, through: :dispatch_customer_orders
  has_many :customer_order_products, dependent: :destroy
  has_many :products, through: :customer_order_products
  accepts_nested_attributes_for :customer_order_products, allow_destroy: true
  enum order_status: { New: "New", complete: "Complete", deleted: "Deleted" }
  PRODUCTS = [ "DEF", "Regular", "Plus", "Super", "Eth-Regular", "Eth-Plus", "Eth-Super", "Reg-E10", "Plus-E10", "Super-E10", "ULS", "Dyed ULS" ]
  scope :unassigned_open_orders, -> { where(order_status: 'open').where(dispatch_id: nil) }

  after_create :add_blank_product

  def assign_user_and_create_dispatch
    # Logic to assign user and create a dispatch
    # Example:
    Dispatch.create(customer_order: self, assigned_user: User.first) # Adjust assignment logic as needed
  end

  def unassigned?
    dispatches.empty?
  end

  private

  def add_blank_product
    Rails.logger.info "Adding a blank product to customer order with ID: #{id}"
  
    blank_product = self.customer_order_products.create(quantity: 0, price: 0.0, product_id: 1)
  
    if blank_product.persisted?
      Rails.logger.info "Successfully added blank product: #{blank_product.inspect}"
    else
      Rails.logger.error "Failed to add blank product. Errors: #{blank_product.errors.full_messages.join(', ')}"
    end
  end
end
