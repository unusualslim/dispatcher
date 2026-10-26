class CustomerOrder < ApplicationRecord
  belongs_to :location
  belongs_to :customer, optional: true
  # The warehouse an order entered in the app ships from; PDI orders carry theirs per line.
  belongs_to :ship_from_location, class_name: 'Location', optional: true

  has_many :dispatch_customer_orders, dependent: :destroy
  has_many :dispatches, through: :dispatch_customer_orders

  has_many :customer_order_products, dependent: :destroy
  has_many :products, through: :customer_order_products
  has_and_belongs_to_many :things

  accepts_nested_attributes_for :customer_order_products, allow_destroy: true

  after_save :sync_approximate_amount
  after_save :link_customer_location, if: -> { saved_change_to_customer_id? || saved_change_to_location_id? }

  def sync_approximate_amount
    total = customer_order_products.reload.sum(:quantity).to_f
    update_column(:approximate_product_amount, total) unless approximate_product_amount == total
  end

  # Remember that this customer receives deliveries here, so the order form
  # lists the location first next time. Locations can be shared by customers.
  def link_customer_location
    return unless customer_id && location_id

    CustomerLocation.insert_all(
      [{ customer_id: customer_id, location_id: location_id, created_at: Time.current, updated_at: Time.current }],
      unique_by: %i[customer_id location_id]
    )
  end

  attribute :freight_only, :boolean, default: false

  enum :order_status, {
    open_order: 'Open Order',
    quote: 'Quote',
    pending: 'Pending',
    released_for_dispatch: 'Released for Dispatch',
    dispatched: 'Dispatched',
    released_for_picking: 'Released for Picking',
    picking_in_progress: 'Picking in Progress',
    shipped: 'Shipped',
    released_for_billing: 'Released for Billing',
    billed: 'Billed',
    delivered: 'Delivered',
    accepted_by_site: 'Accepted by Site',
    rejected_by_site: 'Rejected by Site',
    expired: 'Expired',
    expired_quote: 'Expired Quote',
    cancelled_as_order: 'Cancelled as Order',
    cancelled_as_quote: 'Cancelled as Quote',
    quarantine: 'Quarantine',
    credited: 'Credited',
    staged: 'Staged',
    truck_loaded: 'Loaded' # key can't be "loaded" (ActiveRecord::Relation#loaded)
  }

  # Statuses that represent active/open work (equivalent to the old "New")
  ACTIVE_STATUSES = [
    'Open Order', 'Quote', 'Pending', 'Released for Dispatch', 'Dispatched',
    'Released for Picking', 'Picking in Progress', 'Released for Billing', 'Staged', 'Loaded'
  ].freeze

  PRODUCTS = ['DEF', 'Regular', 'Plus', 'Super', 'Eth-Regular', 'Eth-Plus', 'Eth-Super', 'Reg-E10', 'Plus-E10',
              'Super-E10', 'ULS', 'Dyed ULS']
  # PDI carriers whose orders our own drivers deliver: 1514 Five Points Logistics, 1512 Five Points Service.
  DISPATCH_CARRIER_IDS = %w[1514 1512].freeze
  # Orders from the old FTP import only have the carrier's name.
  DISPATCH_CARRIER_NAMES = ['Five Points Logistics, LLC', 'Five Points Service, Inc.'].freeze

  # Orders the dispatch board can assign: entered in the app, or a PDI order carried by our own trucks.
  scope :dispatchable, lambda {
    where(external_order_no: nil)
      .or(where(pdi_carrier_id: DISPATCH_CARRIER_IDS))
      .or(where(pdi_carrier_id: nil, carrier: DISPATCH_CARRIER_NAMES))
  }

  scope :unassigned_open_orders, lambda {
    where(order_status: ACTIVE_STATUSES).where.not(id: joins(:dispatch_customer_orders).select(:id))
  }

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
