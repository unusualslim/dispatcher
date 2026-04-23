class Vendor < ApplicationRecord
    has_many :dispatches
    has_many :purchase_orders
    validates :name, presence: true, uniqueness: true
end
