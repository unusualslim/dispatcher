class StandardCostHistory < ApplicationRecord
  belongs_to :product
  belongs_to :created_by, class_name: 'User', optional: true

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :effective_date, presence: true
end
