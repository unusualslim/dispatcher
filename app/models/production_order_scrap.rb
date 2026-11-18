# Scrap recorded on a production order: the finished product or a component (product), how much, and why.
class ProductionOrderScrap < ApplicationRecord
  include Audited

  audited

  belongs_to :production_order
  belongs_to :scrap_reason
  belongs_to :product, optional: true
  belongs_to :recorded_by, class_name: 'User', optional: true

  validates :quantity, numericality: { greater_than: 0 }
end
