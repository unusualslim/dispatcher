class Product < ApplicationRecord
  include ProductCosting

  has_many :location_products
  has_many :locations, through: :location_products

  has_many :customer_order_products, dependent: :destroy
  has_many :customer_orders, through: :customer_order_products

  has_many :product_components, dependent: :destroy
  has_many :component_products, through: :product_components, source: :component_product
  has_many :component_of, class_name: 'ProductComponent', foreign_key: :component_product_id
  has_many :product_cost_lines, -> { order(:position, :id) }, dependent: :destroy
  has_many :quality_specs, -> { order(:position, :id) }, dependent: :destroy
  # PDI's reporting group for the product, matched by category name (fuel or warehouse).
  belongs_to :reporting_group, foreign_key: :category, primary_key: :name, optional: true, inverse_of: :products

  has_many :production_order_components
  has_many :inventory_transactions
  has_many :standard_cost_histories, -> { order(effective_date: :desc, created_at: :desc) }, dependent: :destroy
  has_many :inventory_cost_histories, -> { order(created_at: :desc) }, dependent: :destroy
  has_many :purchase_order_line_items, primary_key: :id
  has_many :purchase_orders, through: :purchase_order_line_items

  has_many :product_vendors, -> { order(:priority) }, dependent: :destroy
  has_many :vendors, through: :product_vendors

  accepts_nested_attributes_for :product_components, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :product_cost_lines, allow_destroy: true, reject_if: ->(a) { a['description'].blank? }
  accepts_nested_attributes_for :quality_specs, allow_destroy: true, reject_if: ->(a) { a['name'].blank? }

  validates :name, presence: true
  validates :id, presence: true

  after_save :record_inventory_cost_change, if: :saved_change_to_cost_per_unit?
  after_save -> { ReportingGroup.ensure_for_category!(category) },
             if: -> { saved_change_to_category? && category.present? }

  scope :raw_materials,       -> { where(is_raw_material: true) }
  scope :finished_goods,      -> { where(is_raw_material: false) }
  scope :below_reorder_point, -> { raw_materials.where('current_stock <= reorder_point AND reorder_point IS NOT NULL') }
  # Inactive products (set by hand or from PDI) stay on their history but leave pickers.
  scope :active,              -> { where(active: true) }

  # Picker list: active products plus any already chosen, so editing a record never drops its product.
  def self.selectable(*keep_ids)
    active.or(where(id: keep_ids.flatten.compact))
  end

  # Item types that are bought or delivered as-is, never made here.
  NOT_PRODUCED_ITEM_TYPES = %w[fuel non_inventory].freeze

  # Whether a sold line of this product goes to production planning: not raw materials, and not fuel or
  # non-inventory items (diesel, gasoline, Freight - DEF…), which are bought or delivered as-is.
  def produced?
    !is_raw_material? && NOT_PRODUCED_ITEM_TYPES.exclude?(reporting_group&.item_type)
  end

  # Order line item type for this product (customer_order_products.item_type).
  def order_item_type
    produced? ? 'production' : 'buy'
  end

  # Stock at a specific warehouse location.
  # Returns 0 if no location_product row exists for this location yet.
  def stock_at(location)
    return current_stock if location.nil?

    location_products.find_by(location_id: location.is_a?(Location) ? location.id : location)&.quantity.to_d
  end

  def primary_vendor
    product_vendors.first&.vendor
  end

  def set_vendors_in_order(vendor_ids)
    vendor_ids = Array(vendor_ids).reject(&:blank?)
    transaction do
      product_vendors.destroy_all
      vendor_ids.each_with_index do |vid, i|
        product_vendors.create!(vendor_id: vid, priority: i + 1)
      end
    end
  end

  # Quantity inbound from active purchase orders (not yet received).
  # Uses preloaded value if set by controller bulk query.
  def on_order_qty
    return @on_order_qty if defined?(@on_order_qty)

    purchase_order_line_items
      .joins(:purchase_order)
      .where(purchase_orders: { status: %w[draft pending_approval approved submitted] })
      .sum(:quantity)
  end

  # Quantity committed to open production orders (created or in_progress).
  # Uses preloaded value if set by controller bulk query.
  def committed_qty
    return @committed_qty if defined?(@committed_qty)

    ProductionOrderComponent
      .joins(:production_order)
      .where(product_id: id)
      .where(production_orders: { status: ProductionOrder::OPEN_STATUSES })
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

  private

  def record_inventory_cost_change
    previous, current = saved_change_to_cost_per_unit
    inventory_cost_histories.create!(amount: current, previous_amount: previous)
  end
end
