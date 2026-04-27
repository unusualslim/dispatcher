class AddCompletedAtToProductionOrderBatches < ActiveRecord::Migration[7.0]
  def change
    add_column :production_order_batches, :completed_at, :datetime
  end
end
