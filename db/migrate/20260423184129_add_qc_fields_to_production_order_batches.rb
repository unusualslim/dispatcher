class AddQcFieldsToProductionOrderBatches < ActiveRecord::Migration[7.0]
  def change
    add_column :production_order_batches, :lot_number, :string
    add_column :production_order_batches, :qc_status, :string, default: 'pending'
    add_column :production_order_batches, :qc_notes, :text
    add_column :production_order_batches, :qc_by, :string
    add_column :production_order_batches, :qc_at, :datetime
    add_index :production_order_batches, :lot_number, unique: true
  end
end
