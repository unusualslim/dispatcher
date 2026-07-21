class Vendor < ApplicationRecord
    has_many :dispatches
    has_many :purchase_orders
    has_many :product_vendors, dependent: :destroy
    has_many :products, through: :product_vendors
    validates :name, presence: true, uniqueness: true
end
