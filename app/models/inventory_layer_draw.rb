# The quantity an issue took from a FIFO layer, kept so a reversal can put it back.
class InventoryLayerDraw < ApplicationRecord
  belongs_to :inventory_transaction
  belongs_to :inventory_cost_layer
end
