class CreateProductionOrderComponents < ActiveRecord::Migration[7.0]
  def change
    create_table :production_order_components do |t|
      t.references :production_order, null: false, foreign_key: true

      t.decimal :quantity, precision: 12, scale: 3
      t.string  :uom
      t.string  :part_number
      t.string  :description
      t.string  :confirmed_by

      t.integer :position

      t.timestamps
    end

    add_index :production_order_components,
          [:production_order_id, :position],
          name: "idx_poc_on_po_id_pos"
  end
end

