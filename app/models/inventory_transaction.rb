class InventoryTransaction < ApplicationRecord
  belongs_to :product
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :transactable, polymorphic: true, optional: true
  belongs_to :reversal_of, class_name: 'InventoryTransaction', optional: true
  has_one :reversal, class_name: 'InventoryTransaction', foreign_key: :reversal_of_id, inverse_of: :reversal_of,
                     dependent: :restrict_with_error

  # Moves still in effect: not themselves reversals, and not reversed yet.
  scope :in_effect, -> { where(reversal_of_id: nil).where.missing(:reversal) }

  validates :direction, inclusion: { in: %w[in out] }
  validates :quantity,  numericality: { greater_than: 0 }

  scope :inbound,  -> { where(direction: 'in') }
  scope :outbound, -> { where(direction: 'out') }
end
