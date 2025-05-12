class Thing < ApplicationRecord
    belongs_to :dispatches, optional: true

    validates :category, inclusion: { in: %w[truck trailer], message: "%{value} is not a valid category" }
end
