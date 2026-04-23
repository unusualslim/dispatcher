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
  has_many :purchase_orders

  accepts_nested_attributes_for :product_components, allow_destroy: true

  validates :name, presence: true

  scope :raw_materials,       -> { where(is_raw_material: true) }
  scope :finished_goods,      -> { where(is_raw_material: false) }
  scope :below_reorder_point, -> { raw_materials.where('current_stock <= reorder_point AND reorder_point IS NOT NULL') }

  def available_stock
    [(current_stock || 0) - (safety_stock || 0), 0].max
  end

  def stock_status
    return :unknown if reorder_point.nil?
    if current_stock <= (safety_stock || 0)
      :critical
    elsif current_stock <= reorder_point
      :low
    else
      :ok
    end
  end
end