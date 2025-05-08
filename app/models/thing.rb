class Thing < ApplicationRecord
    has_and_belongs_to_many :dispatches
    has_and_belongs_to_many :customer_orders
end
