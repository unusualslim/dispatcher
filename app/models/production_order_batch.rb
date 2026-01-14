class ProductionOrderBatch < ApplicationRecord
  belongs_to :production_order
  validates :batch_number, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end
