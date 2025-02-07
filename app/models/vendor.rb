class Vendor < ApplicationRecord
    has_many :dispatches
    validates :name, presence: true, uniqueness: true
end
