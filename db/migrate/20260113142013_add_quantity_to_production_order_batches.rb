class AddQuantityToProductionOrderBatches < ActiveRecord::Migration[7.0]
  def change
    add_column :production_order_batches, :quantity, :decimal, precision: 12, scale: 3
  end
end
