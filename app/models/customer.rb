class Customer < ApplicationRecord
    has_many :customer_locations
    has_many :locations, through: :customer_locations
end
