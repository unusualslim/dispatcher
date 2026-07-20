class Product < ApplicationRecord
  has_many :location_products
  has_many :locations, through: :location_products

  has_many :customer_order_products, dependent: :destroy
  has_many :customer_orders, through: :customer_order_products

  has_many :product_components, dependent: :destroy
  has_many :component_products, through: :product_components, source: :component_product
  has_many :component_of, class_name: 'ProductComponent', foreign_key: :component_product_id

  has_many :production_order_components
  has_many :inventory_transactions
  has_many :purchase_order_line_items, foreign_key: :product_id, primary_key: :id
  has_many :purchase_orders, through: :purchase_order_line_items

  accepts_nested_attributes_for :product_components, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :id, presence: true

  scope :raw_materials,       -> { where(is_raw_material: true) }
  scope :finished_goods,      -> { where(is_raw_material: false) }
  scope :below_reorder_point, -> { raw_materials.where('current_stock <= reorder_point AND reorder_point IS NOT NULL') }

  # Quantity inbound from active purchase orders (not yet received).
  # Uses preloaded value if set by controller bulk query.
  def on_order_qty
    return @on_order_qty if defined?(@on_order_qty)
    purchase_order_line_items
      .joins(:purchase_order)
      .where(purchase_orders: { status: %w[draft pending_approval approved submitted] })
      .sum(:quantity)
  end

  # Quantity committed to open production orders (pending or in_progress).
  # Uses preloaded value if set by controller bulk query.
  def committed_qty
    return @committed_qty if defined?(@committed_qty)
    ProductionOrderComponent
      .joins(:production_order)
      .where(product_id: id)
      .where(production_orders: { status: %w[pending in_progress] })
      .sum(:quantity)
  end

  # Physical stock + inbound POs
  def projected_stock
    (current_stock || 0) + on_order_qty
  end

  # What's left after fulfilling all open production orders
  def available_stock
    projected_stock - committed_qty
  end

  def stock_status
    return :unknown if reorder_point.nil?
    if projected_stock < committed_qty
      :critical
    elsif (current_stock || 0) <= reorder_point
      :low
    else
      :ok
    end
  end
end