class InventoryTransaction < ApplicationRecord
  # What moved the stock. Older rows (before costing) have no type and no cost.
  MOVEMENT_TYPES = {
    'opening' => 'Opening balance',
    'receipt' => 'Receipt',
    'sale' => 'Sale',
    'production_use' => 'Production use',
    'production_output' => 'Production output',
    'adjustment' => 'Adjustment',
    'pdi_sync' => 'PDI sync',
    'revaluation' => 'Revaluation'
  }.freeze
  # Movements that change value only (quantity 0).
  VALUE_ONLY_TYPES = %w[opening revaluation].freeze

  belongs_to :product
  belongs_to :location, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :transactable, polymorphic: true, optional: true
  belongs_to :reversal_of, class_name: 'InventoryTransaction', optional: true
  belongs_to :ledger_entry, optional: true
  has_one :reversal, class_name: 'InventoryTransaction', foreign_key: :reversal_of_id, inverse_of: :reversal_of,
                     dependent: :restrict_with_error
  has_many :inventory_layer_draws, dependent: :destroy

  # Moves still in effect: not themselves reversals, and not reversed yet.
  scope :in_effect, -> { where(reversal_of_id: nil).where.missing(:reversal) }
  scope :costed, -> { where.not(movement_type: nil) }

  validates :direction, inclusion: { in: %w[in out] }
  validates :movement_type, inclusion: { in: MOVEMENT_TYPES.keys }, allow_nil: true
  validates :quantity, numericality: { greater_than: 0 }, unless: :value_only?
  validates :quantity, numericality: { equal_to: 0 }, if: :value_only?

  scope :inbound,  -> { where(direction: 'in') }
  scope :outbound, -> { where(direction: 'out') }

  def value_only?
    VALUE_ONLY_TYPES.include?(movement_type)
  end

  def movement_type_label
    MOVEMENT_TYPES[movement_type] || 'Legacy'
  end

  def signed_quantity
    direction == 'in' ? quantity : -quantity
  end

  def signed_value
    return nil if total_cost.nil?

    direction == 'in' ? total_cost : -total_cost
  end
end
