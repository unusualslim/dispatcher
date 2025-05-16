class Thing < ApplicationRecord
    belongs_to :dispatches, optional: true
    has_many :work_orders, as: :workable, dependent: :destroy

    validates :category, inclusion: { in: %w[truck trailer], message: "%{value} is not a valid category" }
end
