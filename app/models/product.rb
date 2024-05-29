class Product < ApplicationRecord
    has_many :location_products
    has_many :locations, through: :location_products

    validates :name, presence: true
end
