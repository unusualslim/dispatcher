class InventoryTransaction < ApplicationRecord
  belongs_to :product
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :transactable, polymorphic: true, optional: true

  validates :direction, inclusion: { in: %w[in out] }
  validates :quantity,  numericality: { greater_than: 0 }

  scope :inbound,  -> { where(direction: 'in') }
  scope :outbound, -> { where(direction: 'out') }
end
