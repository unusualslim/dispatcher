class CustomerOrder < ApplicationRecord
  belongs_to :location
  belongs_to :customer, optional: true

  has_many :dispatch_customer_orders, dependent: :destroy
  has_many :dispatches, through: :dispatch_customer_orders

  has_many :customer_order_products, dependent: :destroy
  has_many :products, through: :customer_order_products
  has_and_belongs_to_many :things

  accepts_nested_attributes_for :customer_order_products, allow_destroy: true

  after_save :sync_approximate_amount

  def sync_approximate_amount
    total = customer_order_products.reload.sum(:quantity).to_f
    update_column(:approximate_product_amount, total) unless approximate_product_amount == total
  end

  attribute :freight_only, :boolean, default: false

  enum order_status: {
    open_order:            "Open Order",
    quote:                 "Quote",
    pending:               "Pending",
    released_for_dispatch: "Released for Dispatch",
    dispatched:            "Dispatched",
    released_for_picking:  "Released for Picking",
    picking_in_progress:   "Picking in Progress",
    shipped:               "Shipped",
    released_for_billing:  "Released for Billing",
    billed:                "Billed",
    delivered:             "Delivered",
    accepted_by_site:      "Accepted by Site",
    rejected_by_site:      "Rejected by Site",
    expired:               "Expired",
    cancelled_as_order:    "Cancelled as Order",
    cancelled_as_quote:    "Cancelled as Quote",
  }

  # Statuses that represent active/open work (equivalent to the old "New")
  ACTIVE_STATUSES = [
    "Open Order", "Quote", "Pending", "Released for Dispatch", "Dispatched",
    "Released for Picking", "Picking in Progress", "Shipped", "Released for Billing"
  ].freeze

  PRODUCTS = [ "DEF", "Regular", "Plus", "Super", "Eth-Regular", "Eth-Plus", "Eth-Super", "Reg-E10", "Plus-E10", "Super-E10", "ULS", "Dyed ULS" ]
  scope :unassigned_open_orders, -> { where(order_status: ACTIVE_STATUSES).where.not(id: joins(:dispatch_customer_orders).select(:id)) }

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
