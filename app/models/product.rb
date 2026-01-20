class Product < ApplicationRecord
  has_many :location_products
  has_many :locations, through: :location_products

  has_many :customer_order_products, dependent: :destroy
  has_many :customer_orders, through: :customer_order_products

  has_many :product_components, dependent: :destroy
  has_many :component_products, through: :product_components, source: :component_product

  accepts_nested_attributes_for :product_components, allow_destroy: true

  validates :name, presence: true
end