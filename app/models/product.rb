class Product < ApplicationRecord
    has_many :location_products
    has_many :locations, through: :location_products
    has_many :customer_order_products, dependent: :destroy
    has_many :customer_orders, through: :customer_order_products

    validates :name, presence: true
end
