class CreateProductionOrderBatches < ActiveRecord::Migration[7.0]
  def change
    create_table :production_order_batches do |t|
      t.references :production_order, null: false, foreign_key: true
      t.string :batch_number, null: false

      t.timestamps
    end
  end
end
