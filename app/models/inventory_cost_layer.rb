# A FIFO cost layer: stock received at one cost at one location. Issues use up the oldest layers first.
class InventoryCostLayer < ApplicationRecord
  belongs_to :product
  belongs_to :location
  belongs_to :inventory_transaction, optional: true
  has_many :inventory_layer_draws, dependent: :restrict_with_error

  scope :open, -> { where('remaining_quantity > 0') }
  scope :oldest_first, -> { order(:received_on, :id) }
end
