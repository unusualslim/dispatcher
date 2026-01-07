class ProductionOrderBatch < ApplicationRecord
  belongs_to :production_order
  validates :batch_number, presence: true
end
